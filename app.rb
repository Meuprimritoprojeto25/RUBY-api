require "sinatra/base"
require "rack/session/cookie"
require "json"
require "date"
require "securerandom"
require_relative "config/environment"

class DashboardiaApp < Sinatra::Base
  configure do
    set :root, ROOT.to_s
    set :environment, ENV.fetch("RACK_ENV", "development").to_sym
    set :show_exceptions, false
    set :raise_errors, false
    # Browser forms use Rack::Protection's authenticity token. A generated
    # development secret keeps the application runnable in a fresh preview;
    # deployments can provide SESSION_SECRET to retain sessions across restarts.
    set :session_secret, ENV.fetch("SESSION_SECRET") { SecureRandom.hex(64) }
    # Sinatra installs its own Rack::Protection middleware when this setting
    # is enabled. Disable that implicit stack so the explicit configuration
    # below is the only protection middleware in the request path.
    #
    # Without this setting, Sinatra's default HostAuthorization middleware
    # remains active in addition to the stack configured below and rejects
    # preview gateway hostnames with a bare 403 response.
    set :protection, false
  end

  use Rack::Session::Cookie,
      key: "dashboardia.session",
      secret: settings.session_secret,
      same_site: :lax,
      secure: ENV.fetch("RACK_ENV", "development") == "production"
  use Rack::Deflater
  # Preview environments are reached through a gateway whose hostname is not
  # known when the image is built. Keep Rack's request protections enabled,
  # but let the gateway's valid public Host header reach the application.
  # This is deliberately the sole Rack::Protection stack; see the explicit
  # Sinatra configuration above.
  use Rack::Protection, except: [:host_authorization, :authenticity_token]
  # API clients authenticate their own requests and should not need a browser
  # session token. Server-rendered forms include the token generated above.
  use Rack::Protection::AuthenticityToken,
      allow_if: ->(env) { env["PATH_INFO"].start_with?("/api/") }

  before do
    headers(
      "X-Content-Type-Options" => "nosniff",
      "X-Frame-Options" => "DENY",
      "Referrer-Policy" => "strict-origin-when-cross-origin"
    )
    content_type :json if request.path_info.start_with?("/api/", "/health")
  end

  options "*" do
    headers "Allow" => "GET, POST, PATCH, DELETE, OPTIONS"
    status 204
  end

  get "/" do
    @projects = Project.includes(:tasks).recent.limit(6)
    @total_projects = Project.count
    @total_tasks = Task.count
    @completed_tasks = Task.where(state: "done").count
    @in_progress_tasks = Task.where(state: "in_progress").count
    @overdue_tasks = Task.overdue.count
    @completion_percentage = completion_rate
    @upcoming_tasks = Task.includes(:project).due_soon.limit(5)
    @activity_events = ActivityEvent.includes(:project, :task).recent.limit(6)
    @notice = params["notice"].presence
    erb :dashboard
  end

  get "/tasks" do
    @state_filter = params["state"].presence
    @priority_filter = params["priority"].presence
    @tasks = Task.includes(:project).recent
    @tasks = @tasks.where(state: @state_filter) if Task::STATES.include?(@state_filter)
    @tasks = @tasks.where(priority: @priority_filter) if Task::PRIORITIES.include?(@priority_filter)
    erb :tasks
  end

  get "/activity" do
    @activity_events = ActivityEvent.includes(:project, :task).recent.limit(80)
    erb :activity
  end

  get "/projects" do
    @status_filter = params["status"].presence
    @query = params["q"].to_s.strip
    @projects = Project.includes(:tasks).recent
    @projects = @projects.where(status: @status_filter) if Project::STATUSES.include?(@status_filter)

    if @query.present?
      search_term = "%#{ActiveRecord::Base.sanitize_sql_like(@query.downcase)}%"
      @projects = @projects.where(
        "LOWER(projects.name) LIKE :search OR LOWER(projects.code) LIKE :search",
        search: search_term
      )
    end

    erb :projects
  end

  get "/projects/new" do
    @project = Project.new(status: "active", description: "")
    @form_action = "/projects"
    @form_title = "Create a project"
    @form_lead = "Set the name, short code, and current delivery status for a new workspace."
    @submit_label = "Create project"
    erb :project_form
  end

  post "/projects" do
    @project = Project.new(web_project_attributes)

    if @project.save
      record_activity!(@project, "project_created", "Created project “#{@project.name}”.")
      redirect "/projects/#{@project.id}?notice=#{Rack::Utils.escape_path("Project created successfully.")}"
    end

    set_project_form_copy
    status 422
    erb :project_form
  end

  get "/projects/:id/edit" do
    @project = find_project
    set_project_form_copy(editing: true)
    erb :project_form
  end

  post "/projects/:id" do
    @project = find_project
    previous_status = @project.status

    if @project.update(web_project_attributes)
      message = previous_status == @project.status ? "Updated project “#{@project.name}”." : "Changed “#{@project.name}” to #{@project.status}."
      record_activity!(@project, "project_updated", message)
      redirect "/projects/#{@project.id}?notice=#{Rack::Utils.escape_path("Project updated successfully.")}"
    end

    set_project_form_copy(editing: true)
    status 422
    erb :project_form
  end

  post "/projects/:id/delete" do
    project = find_project
    project.destroy!
    redirect "/projects?notice=#{Rack::Utils.escape_path("Project deleted successfully.")}"
  end

  get "/projects/:id" do
    @project = find_project
    @tasks = @project.tasks.recent
    @task_form = @project.tasks.build(state: "todo", priority: "medium")
    @activity_events = @project.activity_events.includes(:task).recent.limit(10)
    @notice = params["notice"].presence
    erb :project
  end

  post "/projects/:id/tasks" do
    @project = find_project
    @task_form = @project.tasks.build(web_task_attributes)

    if @task_form.save
      record_activity!(@project, "task_created", "Added task “#{@task_form.title}”.", task: @task_form)
      redirect "/projects/#{@project.id}?notice=#{Rack::Utils.escape_path("Task added to the project.")}"
    end

    @tasks = @project.tasks.recent
    @activity_events = @project.activity_events.includes(:task).recent.limit(10)
    status 422
    erb :project
  rescue Date::Error
    @tasks = @project.tasks.recent
    @activity_events = @project.activity_events.includes(:task).recent.limit(10)
    @task_form ||= @project.tasks.build
    @task_form.errors.add(:due_on, "must use the YYYY-MM-DD format")
    status 422
    erb :project
  end

  post "/tasks/:id/complete" do
    task = find_task
    task.update!(state: "done")
    record_activity!(task.project, "task_completed", "Completed task “#{task.title}”.", task: task)
    redirect "/projects/#{task.project_id}?notice=#{Rack::Utils.escape_path("Task marked as complete.")}"
  end

  get "/tasks/:id/edit" do
    @task = find_task
    @project = @task.project
    erb :task_form
  end

  post "/tasks/:id" do
    @task = find_task
    @project = @task.project

    if @task.update(web_task_attributes)
      event_type = @task.state == "done" ? "task_completed" : "task_updated"
      record_activity!(@project, event_type, "Updated task “#{@task.title}”.", task: @task)
      redirect "/projects/#{@project.id}?notice=#{Rack::Utils.escape_path("Task updated successfully.")}"
    end

    status 422
    erb :task_form
  rescue Date::Error
    @task ||= find_task
    @project ||= @task.project
    @task.errors.add(:due_on, "must use the YYYY-MM-DD format")
    status 422
    erb :task_form
  end

  post "/tasks/:id/delete" do
    task = find_task
    project = task.project
    record_activity!(project, "task_deleted", "Removed task “#{task.title}”.", task: task)
    task.destroy!
    redirect "/projects/#{project.id}?notice=#{Rack::Utils.escape_path("Task deleted successfully.")}"
  end

  get "/health" do
    Database.prepare!
    json_response(status: "ok", database: "connected", time: Time.now.utc.iso8601)
  end

  get "/api/v1/dashboard" do
    json_response(
      data: {
        projects: Project.count,
        tasks: Task.count,
        completed_tasks: Task.where(state: "done").count,
        in_progress_tasks: Task.where(state: "in_progress").count,
        overdue_tasks: Task.overdue.count,
        completion_rate: completion_rate
      }
    )
  end

  get "/api/v1/projects" do
    projects = Project.includes(:tasks).recent
    projects = projects.where(status: params["status"]) if params["status"].present?
    json_response(data: projects.map { |project| project_payload(project, include_tasks: false) })
  end

  post "/api/v1/projects" do
    project = Project.create!(project_attributes(json_body))
    record_activity!(project, "project_created", "Created project “#{project.name}” through the API.")
    json_response({ data: project_payload(project) }, 201)
  end

  get "/api/v1/projects/:id" do
    json_response(data: project_payload(find_project, include_tasks: true))
  end

  patch "/api/v1/projects/:id" do
    project = find_project
    project.update!(project_attributes(json_body))
    record_activity!(project, "project_updated", "Updated project “#{project.name}” through the API.")
    json_response(data: project_payload(project, include_tasks: true))
  end

  delete "/api/v1/projects/:id" do
    find_project.destroy!
    status 204
  end

  get "/api/v1/projects/:project_id/tasks" do
    project = Project.find(params["project_id"])
    tasks = project.tasks.recent
    tasks = tasks.where(state: params["state"]) if params["state"].present?
    json_response(data: tasks.map { |task| task_payload(task) })
  end

  post "/api/v1/projects/:project_id/tasks" do
    project = Project.find(params["project_id"])
    task = project.tasks.create!(task_attributes(json_body))
    record_activity!(project, "task_created", "Added task “#{task.title}” through the API.", task: task)
    json_response({ data: task_payload(task) }, 201)
  end

  get "/api/v1/tasks/:id" do
    json_response(data: task_payload(find_task))
  end

  patch "/api/v1/tasks/:id" do
    task = find_task
    task.update!(task_attributes(json_body))
    event_type = task.state == "done" ? "task_completed" : "task_updated"
    record_activity!(task.project, event_type, "Updated task “#{task.title}” through the API.", task: task)
    json_response(data: task_payload(task))
  end

  delete "/api/v1/tasks/:id" do
    task = find_task
    record_activity!(task.project, "task_deleted", "Removed task “#{task.title}” through the API.", task: task)
    task.destroy!
    status 204
  end

  get "/api/v1/activity" do
    events = ActivityEvent.includes(:project, :task).recent
    events = events.where(project_id: params["project_id"]) if params["project_id"].present?
    json_response(data: events.limit(100).map { |event| activity_payload(event) })
  end

  not_found do
    if request.path_info.start_with?("/api/", "/health")
      json_response({ error: { code: "not_found", message: "Route not found" } }, 404)
    end

    erb :not_found
  end

  error ActiveRecord::RecordNotFound do
    if request.path_info.start_with?("/api/", "/health")
      json_response({ error: { code: "not_found", message: "Record not found" } }, 404)
    else
      status 404
      erb :not_found
    end
  end

  error ActiveRecord::RecordInvalid do
    exception = env["sinatra.error"]
    json_response(
      { error: { code: "validation_failed", message: "One or more fields are invalid", details: exception.record.errors.to_hash } },
      422
    )
  end

  error JSON::ParserError do
    json_response({ error: { code: "invalid_json", message: "Request body must be valid JSON" } }, 400)
  end

  error Date::Error do
    json_response({ error: { code: "invalid_date", message: "Dates must use the YYYY-MM-DD format" } }, 400)
  end

  error do
    exception = env["sinatra.error"]
    logger.error("#{exception.class}: #{exception.message}\n#{exception.backtrace&.join("\n")}")
    json_response({ error: { code: "internal_error", message: "An unexpected error occurred" } }, 500)
  end

  helpers do
    def json_response(payload, response_status = 200)
      content_type :json
      status response_status
      JSON.generate(payload)
    end

    def json_body
      request.body.rewind
      body = request.body.read
      return {} if body.strip.empty?

      JSON.parse(body)
    end

    def project_attributes(body)
      permitted_attributes(body, "name", "code", "description", "status")
    end

    def web_project_attributes
      {
        name: params["name"].to_s.strip,
        code: params["code"].to_s.strip.downcase,
        description: params["description"].to_s.strip,
        status: params["status"].presence || "active"
      }
    end

    def task_attributes(body)
      attributes = permitted_attributes(body, "title", "description", "state", "priority", "due_on")
      attributes["due_on"] = Date.iso8601(attributes["due_on"]) if attributes["due_on"].present?
      attributes
    end

    def web_task_attributes
      due_on = params["due_on"].to_s.strip

      {
        title: params["title"].to_s.strip,
        description: params["description"].to_s.strip,
        state: params["state"].presence || "todo",
        priority: params["priority"].presence || "medium",
        due_on: due_on.empty? ? nil : Date.iso8601(due_on)
      }
    end

    def permitted_attributes(body, *allowed)
      body.slice(*allowed)
    end

    def find_project
      Project.find(params["id"])
    end

    def find_task
      Task.find(params["id"])
    end

    def set_project_form_copy(editing: false)
      @form_action = editing ? "/projects/#{@project.id}" : "/projects"
      @form_title = editing ? "Edit project" : "Create a project"
      @form_lead = editing ? "Keep the scope, delivery status, and project details current." : "Set the name, short code, and current delivery status for a new workspace."
      @submit_label = editing ? "Save changes" : "Create project"
    end

    def record_activity!(project, event_type, message, task: nil)
      project.activity_events.create!(event_type: event_type, message: message, task: task)
    end

    def project_payload(project, include_tasks: true)
      {
        id: project.id,
        name: project.name,
        code: project.code,
        description: project.description,
        status: project.status,
        task_count: project.tasks.size,
        created_at: project.created_at.iso8601,
        updated_at: project.updated_at.iso8601,
        tasks: include_tasks ? project.tasks.recent.map { |task| task_payload(task) } : nil
      }.compact
    end

    def task_payload(task)
      {
        id: task.id,
        project_id: task.project_id,
        title: task.title,
        description: task.description,
        state: task.state,
        priority: task.priority,
        due_on: task.due_on&.iso8601,
        created_at: task.created_at.iso8601,
        updated_at: task.updated_at.iso8601
      }
    end

    def activity_payload(event)
      {
        id: event.id,
        event_type: event.event_type,
        message: event.message,
        project: { id: event.project_id, name: event.project.name, code: event.project.code },
        task: event.task ? { id: event.task_id, title: event.task.title } : nil,
        created_at: event.created_at.iso8601
      }.compact
    end

    def completion_rate
      total = Task.count
      return 0 if total.zero?

      ((Task.where(state: "done").count.to_f / total) * 100).round
    end

    def h(value)
      Rack::Utils.escape_html(value.to_s)
    end

    def csrf_field
      token = session[:csrf] ||= SecureRandom.urlsafe_base64(32)
      %(<input type="hidden" name="authenticity_token" value="#{h(token)}">)
    end

    def project_completion(project)
      total = project.tasks.size
      return 0 if total.zero?

      ((project.tasks.count { |task| task.state == "done" }.to_f / total) * 100).round
    end

    def event_label(event)
      event.event_type.tr("_", " ").sub(/\A./, &:upcase)
    end

    def project_status_options(selected)
      Project::STATUSES.map do |value|
        selected_attribute = value == selected ? " selected" : ""
        %(<option value="#{value}"#{selected_attribute}>#{value.capitalize}</option>)
      end.join
    end

    def task_state_options(selected)
      Task::STATES.map do |value|
        selected_attribute = value == selected ? " selected" : ""
        label = value.tr("_", " ").capitalize
        %(<option value="#{value}"#{selected_attribute}>#{label}</option>)
      end.join
    end

    def task_priority_options(selected)
      Task::PRIORITIES.map do |value|
        selected_attribute = value == selected ? " selected" : ""
        %(<option value="#{value}"#{selected_attribute}>#{value.capitalize}</option>)
      end.join
    end

    def errors_for(record, field)
      return "" unless record&.errors&.[](field)&.any?

      %(<p class="field-error">#{h(record.errors[field].join(", "))}</p>)
    end
  end

  template :layout do
    <<~HTML
      <!doctype html>
      <html lang="en">
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1">
          <title>Dashboardia | Work overview</title>
          <style>
            :root { color-scheme:dark; --bg:#0b1020; --panel:#151d33; --panel-strong:#1b2744; --muted:#91a0bd; --line:#293653; --text:#f3f6ff; --accent:#91aaff; --green:#47d7a7; --amber:#ffc76b; --danger:#ff9fa8; }
            * { box-sizing:border-box; } body { margin:0; font-family:Inter,ui-sans-serif,system-ui,-apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif; background:radial-gradient(circle at 90% 0%,#202c57 0,var(--bg) 38rem); color:var(--text); }
            main { max-width:1120px; margin:auto; padding:38px 24px 64px; } header { display:flex; justify-content:space-between; align-items:center; gap:20px; margin-bottom:38px; } .brand { color:var(--text); font-weight:800; letter-spacing:-.04em; font-size:22px; text-decoration:none; } .brand i { color:var(--accent); font-style:normal; } nav { display:flex; align-items:center; gap:8px; flex-wrap:wrap; } a { color:var(--accent); } .nav-link,.button { display:inline-flex; justify-content:center; align-items:center; border:1px solid var(--line); border-radius:9px; padding:9px 12px; color:#d9e2ff; font-size:13px; line-height:1; text-decoration:none; background:transparent; cursor:pointer; font-family:inherit; } .nav-link:hover,.button:hover { border-color:var(--accent); } .button-primary { border-color:var(--accent); color:#0d1630; background:var(--accent); font-weight:700; } .button-danger { border-color:rgba(255,159,168,.5); color:var(--danger); } .button-quiet { padding:7px 10px; font-size:12px; } h1 { font-size:clamp(30px,5vw,48px); max-width:700px; margin:0 0 12px; letter-spacing:-.055em; line-height:1.05; } h2 { margin:0; font-size:18px; } h3 { margin:0; font-size:16px; } .lead { color:var(--muted); max-width:650px; line-height:1.55; margin:0 0 30px; } .grid { display:grid; grid-template-columns:repeat(4,1fr); gap:14px; margin-bottom:28px; } .metric,.project,.form-card,.task,.activity { border:1px solid var(--line); background:rgba(21,29,51,.86); border-radius:15px; } .metric { padding:18px; } .metric span { color:var(--muted); display:block; font-size:13px; margin-bottom:10px; } .metric strong { font-size:29px; letter-spacing:-.04em; } .section-head { display:flex; justify-content:space-between; align-items:center; gap:16px; margin:25px 0 12px; } .projects { display:grid; grid-template-columns:repeat(2,1fr); gap:14px; } .project { padding:20px; color:inherit; text-decoration:none; transition:border-color .15s,transform .15s; } a.project:hover { border-color:var(--accent); transform:translateY(-2px); } .project-top,.task-top { display:flex; justify-content:space-between; align-items:flex-start; gap:10px; } .project p,.task p { color:var(--muted); font-size:14px; line-height:1.45; min-height:40px; } .tag { font-size:12px; padding:4px 8px; border-radius:20px; background:#202c4b; color:#bdc9eb; text-transform:capitalize; white-space:nowrap; } .tag.done { background:rgba(71,215,167,.13); color:var(--green); } .tag.in-progress { background:rgba(255,199,107,.14); color:var(--amber); } .task-line { border-top:1px solid var(--line); padding-top:12px; font-size:13px; color:#c9d3ed; display:flex; justify-content:space-between; gap:12px; } .empty { padding:34px; border:1px dashed var(--line); color:var(--muted); border-radius:15px; text-align:center; } .notice { margin:0 0 24px; padding:12px 14px; border:1px solid rgba(71,215,167,.4); border-radius:10px; background:rgba(71,215,167,.08); color:#c1ffe9; } .toolbar { display:flex; justify-content:space-between; gap:16px; align-items:end; margin-bottom:22px; } .filters { display:flex; gap:8px; flex-wrap:wrap; } .filters input { min-width:200px; } .form-card { padding:24px; max-width:760px; } .form-grid { display:grid; grid-template-columns:repeat(2,1fr); gap:16px; } label { display:block; color:#cbd6f1; font-size:13px; font-weight:650; } input,textarea,select { width:100%; margin-top:7px; border:1px solid var(--line); border-radius:9px; background:#0d1428; color:var(--text); padding:10px 11px; font:inherit; } textarea { min-height:110px; resize:vertical; } input:focus,textarea:focus,select:focus { outline:2px solid rgba(145,170,255,.55); border-color:var(--accent); } .form-actions,.inline-actions { display:flex; align-items:center; gap:12px; margin-top:20px; flex-wrap:wrap; } .inline-actions { margin-top:0; } .inline-actions form { margin:0; } .field-error { color:var(--danger); font-size:12px; margin:6px 0 0; } .form-error { color:var(--danger); margin:0 0 16px; } .project-hero { display:flex; justify-content:space-between; align-items:flex-start; gap:24px; margin-bottom:24px; } .project-hero h1 { font-size:clamp(28px,4vw,40px); } .project-code,.task-meta { color:var(--muted); font-size:13px; } .task-list,.activity-list { display:grid; gap:10px; margin-bottom:28px; } .task { padding:16px; } .task p { min-height:0; margin:8px 0; } .task-foot { display:flex; justify-content:space-between; align-items:center; gap:12px; border-top:1px solid var(--line); padding-top:11px; } .activity { padding:14px 16px; } .activity p { margin:0 0 6px; color:#dce5ff; } .activity small { color:var(--muted); } .progress { height:7px; border-radius:999px; background:#0d1428; overflow:hidden; margin:12px 0 4px; } .progress span { display:block; height:100%; border-radius:inherit; background:linear-gradient(90deg,var(--accent),var(--green)); } .two-column { display:grid; grid-template-columns:1.2fr .8fr; gap:18px; } .due-overdue { color:var(--danger); } .muted { color:var(--muted); } code { color:#ccd7ff; } @media(max-width:720px) { .grid { grid-template-columns:repeat(2,1fr); } .projects,.two-column { grid-template-columns:1fr; } .project-hero,.toolbar { align-items:stretch; flex-direction:column; } .form-grid { grid-template-columns:1fr; } } @media(max-width:420px) { main { padding:26px 16px 48px; } .grid { grid-template-columns:1fr; } header { align-items:flex-start; flex-direction:column; } .filters input { min-width:0; } }
          </style>
        </head>
        <body><main><%= yield %></main></body>
      </html>
    HTML
  end

  template :dashboard do
    <<~HTML
      <header>
        <a class="brand" href="/">dashboard<i>ia</i></a>
        <nav><a class="nav-link" href="/projects">Projects</a><a class="nav-link" href="/tasks">My work</a><a class="nav-link" href="/activity">Activity</a><a class="button button-primary" href="/projects/new">New project</a></nav>
      </header>
      <h1>A clear view of work that moves the business forward.</h1>
      <p class="lead">Plan projects, track tasks, and keep delivery visible. Every action in this workspace is persisted to the versioned Ruby API.</p>
      <% if @notice %><p class="notice"><%= h(@notice) %></p><% end %>
      <section class="grid">
        <div class="metric"><span>Projects</span><strong><%= @total_projects %></strong></div>
        <div class="metric"><span>All tasks</span><strong><%= @total_tasks %></strong></div>
        <div class="metric"><span>In progress</span><strong><%= @in_progress_tasks %></strong></div>
        <div class="metric"><span>Completed</span><strong><%= @completed_tasks %></strong></div>
        <div class="metric"><span>Completion rate</span><strong><%= @completion_percentage %>%</strong></div>
        <div class="metric"><span>Overdue</span><strong class="<%= "due-overdue" if @overdue_tasks.positive? %>"><%= @overdue_tasks %></strong></div>
      </section>
      <div class="section-head"><h2>Recent projects</h2><a href="/api/v1/projects">View API response →</a></div>
      <% if @projects.any? %>
        <section class="projects">
          <% @projects.each do |project| %>
            <a class="project" href="/projects/<%= project.id %>">
              <div class="project-top"><h3><%= Rack::Utils.escape_html(project.name) %></h3><span class="tag"><%= project.status %></span></div>
              <p><%= Rack::Utils.escape_html(project.description) %></p>
              <div class="task-line"><span><%= project.tasks.size %> task<%= project.tasks.size == 1 ? "" : "s" %></span><span><%= project.code %></span></div>
            </a>
          <% end %>
        </section>
      <% else %>
        <div class="empty">Your workspace is ready. <a href="/projects/new">Create your first project</a>, use <code>POST /api/v1/projects</code>, or enable <code>DASHBOARDIA_DEMO_MODE=true</code> for sample data.</div>
      <% end %>
      <section class="two-column">
        <div>
          <div class="section-head"><h2>Due in the next 7 days</h2><a href="/tasks">Open work queue →</a></div>
          <% if @upcoming_tasks.any? %>
            <section class="task-list">
              <% @upcoming_tasks.each do |task| %>
                <article class="task">
                  <div class="task-top"><div><h3><a href="/projects/<%= task.project_id %>"><%= h(task.title) %></a></h3><p class="task-meta"><%= h(task.project.name) %> · <%= h(task.priority) %> priority</p></div><span class="tag <%= task.state == "in_progress" ? "in-progress" : "" %>"><%= h(task.state.tr("_", " ")) %></span></div>
                  <div class="task-foot"><span class="task-meta">Due <%= task.due_on.strftime("%b %-d") %></span><a class="button button-quiet" href="/tasks/<%= task.id %>/edit">Edit</a></div>
                </article>
              <% end %>
            </section>
          <% else %>
            <div class="empty">No open tasks are due in the next week.</div>
          <% end %>
        </div>
        <div>
          <div class="section-head"><h2>Latest activity</h2><a href="/activity">View all →</a></div>
          <% if @activity_events.any? %>
            <section class="activity-list">
              <% @activity_events.each do |event| %>
                <article class="activity"><p><%= h(event.message) %></p><small><a href="/projects/<%= event.project_id %>"><%= h(event.project.name) %></a> · <%= event.created_at.strftime("%b %-d, %H:%M") %></small></article>
              <% end %>
            </section>
          <% else %>
            <div class="empty">Activity from your project work will appear here.</div>
          <% end %>
        </div>
      </section>
    HTML
  end

  template :projects do
    <<~HTML
      <header>
        <a class="brand" href="/">dashboard<i>ia</i></a>
        <nav><a class="nav-link" href="/tasks">My work</a><a class="nav-link" href="/activity">Activity</a><a class="button button-primary" href="/projects/new">New project</a></nav>
      </header>
      <div class="toolbar">
        <div><h1>Projects</h1><p class="lead">Find a workspace, inspect its delivery status, or start a new initiative.</p></div>
        <form class="filters" method="get" action="/projects">
          <input type="search" name="q" value="<%= h(@query) %>" placeholder="Search name or code" aria-label="Search projects">
          <select name="status" aria-label="Filter by status">
            <option value="">All statuses</option><%= project_status_options(@status_filter) %>
          </select>
          <button class="button" type="submit">Filter</button>
        </form>
      </div>
      <% if @projects.any? %>
        <section class="projects">
          <% @projects.each do |project| %>
            <a class="project" href="/projects/<%= project.id %>">
              <div class="project-top"><h3><%= h(project.name) %></h3><span class="tag"><%= h(project.status) %></span></div>
              <p><%= h(project.description) %></p>
              <div class="progress"><span style="width:<%= project_completion(project) %>%"></span></div>
              <div class="task-line"><span><%= project_completion(project) %>% complete · <%= project.tasks.size %> task<%= project.tasks.size == 1 ? "" : "s" %></span><span><%= h(project.code) %></span></div>
            </a>
          <% end %>
        </section>
      <% else %>
        <div class="empty">No projects match this view. <a href="/projects/new">Create a project</a> to begin.</div>
      <% end %>
    HTML
  end

  template :project_form do
    <<~HTML
      <header>
        <a class="brand" href="/">dashboard<i>ia</i></a>
        <nav><a class="nav-link" href="/projects">All projects</a></nav>
      </header>
      <h1><%= h(@form_title) %></h1>
      <p class="lead"><%= h(@form_lead) %></p>
      <form class="form-card" method="post" action="<%= h(@form_action) %>">
        <%= csrf_field %>
        <% if @project.errors.any? %><p class="form-error">Please correct the highlighted fields and try again.</p><% end %>
        <div class="form-grid">
          <label>Name<input name="name" maxlength="120" required value="<%= h(@project.name) %>"><%= errors_for(@project, :name) %></label>
          <label>Code<input name="code" maxlength="24" required pattern="[a-z0-9-]+" value="<%= h(@project.code) %>" placeholder="website-refresh"><%= errors_for(@project, :code) %></label>
        </div>
        <div class="form-grid">
          <label>Status<select name="status"><%= project_status_options(@project.status) %></select><%= errors_for(@project, :status) %></label>
          <label>Description<textarea name="description" maxlength="2000" placeholder="What outcome is this project driving?"><%= h(@project.description) %></textarea><%= errors_for(@project, :description) %></label>
        </div>
        <div class="form-actions"><button class="button button-primary" type="submit"><%= h(@submit_label) %></button><a class="nav-link" href="/projects">Cancel</a></div>
      </form>
    HTML
  end

  template :project do
    <<~HTML
      <header>
        <a class="brand" href="/">dashboard<i>ia</i></a>
        <nav><a class="nav-link" href="/projects">All projects</a><a class="nav-link" href="/tasks">My work</a><a class="nav-link" href="/api/v1/projects/<%= @project.id %>">JSON API</a></nav>
      </header>
      <section class="project-hero">
        <div><p class="project-code"><%= h(@project.code) %></p><h1><%= h(@project.name) %></h1><p class="lead"><%= h(@project.description) %></p></div>
        <div class="inline-actions"><span class="tag"><%= h(@project.status) %></span><a class="button button-quiet" href="/projects/<%= @project.id %>/edit">Edit project</a><form method="post" action="/projects/<%= @project.id %>/delete" onsubmit="return confirm('Delete this project and all of its tasks?');"><%= csrf_field %><button class="button button-quiet button-danger" type="submit">Delete</button></form></div>
      </section>
      <% if @notice %><p class="notice"><%= h(@notice) %></p><% end %>
      <div class="section-head"><h2>Tasks</h2><span class="muted"><%= @tasks.size %> total</span></div>
      <% if @tasks.any? %>
        <section class="task-list">
          <% @tasks.each do |task| %>
            <article class="task">
              <div class="task-top"><div><h3><%= h(task.title) %></h3><p class="task-meta"><%= h(task.priority) %> priority<% if task.due_on %> · Due <%= task.due_on.strftime("%b %-d, %Y") %><% end %></p></div><span class="tag <%= task.state == "done" ? "done" : task.state == "in_progress" ? "in-progress" : "" %>"><%= h(task.state.tr("_", " ")) %></span></div>
              <% if task.description.present? %><p><%= h(task.description) %></p><% end %>
              <div class="task-foot"><span class="task-meta">Updated <%= task.updated_at.strftime("%b %-d") %></span><div class="inline-actions"><a class="button button-quiet" href="/tasks/<%= task.id %>/edit">Edit</a><% unless task.state == "done" %><form method="post" action="/tasks/<%= task.id %>/complete"><%= csrf_field %><button class="button button-quiet" type="submit">Mark complete</button></form><% end %><form method="post" action="/tasks/<%= task.id %>/delete" onsubmit="return confirm('Delete this task?');"><%= csrf_field %><button class="button button-quiet button-danger" type="submit">Delete</button></form></div></div>
            </article>
          <% end %>
        </section>
      <% else %>
        <div class="empty">No tasks yet. Add the first task below to turn this project into an actionable plan.</div>
      <% end %>
      <div class="section-head"><h2>Add a task</h2></div>
      <form class="form-card" method="post" action="/projects/<%= @project.id %>/tasks">
        <%= csrf_field %>
        <% if @task_form.errors.any? %><p class="form-error">Please correct the highlighted fields and try again.</p><% end %>
        <div class="form-grid">
          <label>Title<input name="title" maxlength="180" required value="<%= h(@task_form.title) %>" placeholder="Describe the next deliverable"><%= errors_for(@task_form, :title) %></label>
          <label>Due date<input name="due_on" type="date" value="<%= @task_form.due_on&.iso8601 %>"><%= errors_for(@task_form, :due_on) %></label>
        </div>
        <div class="form-grid">
          <label>State<select name="state"><%= task_state_options(@task_form.state) %></select><%= errors_for(@task_form, :state) %></label>
          <label>Priority<select name="priority"><%= task_priority_options(@task_form.priority) %></select><%= errors_for(@task_form, :priority) %></label>
        </div>
        <label>Description<textarea name="description" maxlength="5000" placeholder="Add context, acceptance criteria, or a handoff note."><%= h(@task_form.description) %></textarea><%= errors_for(@task_form, :description) %></label>
        <div class="form-actions"><button class="button button-primary" type="submit">Add task</button></div>
      </form>
      <div class="section-head"><h2>Project activity</h2><a href="/api/v1/activity?project_id=<%= @project.id %>">JSON API →</a></div>
      <% if @activity_events.any? %>
        <section class="activity-list">
          <% @activity_events.each do |event| %>
            <article class="activity"><p><%= h(event.message) %></p><small><%= h(event_label(event)) %> · <%= event.created_at.strftime("%b %-d, %Y at %H:%M") %></small></article>
          <% end %>
        </section>
      <% else %>
        <div class="empty">Changes to this project will be recorded here.</div>
      <% end %>
    HTML
  end

  template :tasks do
    <<~HTML
      <header>
        <a class="brand" href="/">dashboard<i>ia</i></a>
        <nav><a class="nav-link" href="/projects">Projects</a><a class="nav-link" href="/activity">Activity</a><a class="button button-primary" href="/projects/new">New project</a></nav>
      </header>
      <div class="toolbar">
        <div><h1>My work</h1><p class="lead">Review every task across the workspace and focus on the next delivery milestone.</p></div>
        <form class="filters" method="get" action="/tasks">
          <select name="state" aria-label="Filter by task state"><option value="">All states</option><%= task_state_options(@state_filter) %></select>
          <select name="priority" aria-label="Filter by priority"><option value="">All priorities</option><%= task_priority_options(@priority_filter) %></select>
          <button class="button" type="submit">Filter</button>
        </form>
      </div>
      <% if @tasks.any? %>
        <section class="task-list">
          <% @tasks.each do |task| %>
            <article class="task">
              <div class="task-top">
                <div><h3><a href="/projects/<%= task.project_id %>"><%= h(task.title) %></a></h3><p class="task-meta"><%= h(task.project.name) %> · <%= h(task.priority) %> priority<% if task.due_on %> · Due <span class="<%= "due-overdue" if task.due_on < Date.current && task.state != "done" %>"><%= task.due_on.strftime("%b %-d, %Y") %></span><% end %></p></div>
                <span class="tag <%= task.state == "done" ? "done" : task.state == "in_progress" ? "in-progress" : "" %>"><%= h(task.state.tr("_", " ")) %></span>
              </div>
              <% if task.description.present? %><p><%= h(task.description) %></p><% end %>
              <div class="task-foot"><span class="task-meta">Updated <%= task.updated_at.strftime("%b %-d") %></span><div class="inline-actions"><a class="button button-quiet" href="/tasks/<%= task.id %>/edit">Edit</a><% unless task.state == "done" %><form method="post" action="/tasks/<%= task.id %>/complete"><%= csrf_field %><button class="button button-quiet" type="submit">Mark complete</button></form><% end %></div></div>
            </article>
          <% end %>
        </section>
      <% else %>
        <div class="empty">No tasks match this view. Create a project or change the filters to see work.</div>
      <% end %>
    HTML
  end

  template :task_form do
    <<~HTML
      <header>
        <a class="brand" href="/">dashboard<i>ia</i></a>
        <nav><a class="nav-link" href="/projects/<%= @project.id %>">Back to project</a><a class="nav-link" href="/tasks">My work</a></nav>
      </header>
      <h1>Edit task</h1>
      <p class="lead">Update the delivery details for <a href="/projects/<%= @project.id %>"><%= h(@project.name) %></a>.</p>
      <form class="form-card" method="post" action="/tasks/<%= @task.id %>">
        <%= csrf_field %>
        <% if @task.errors.any? %><p class="form-error">Please correct the highlighted fields and try again.</p><% end %>
        <div class="form-grid">
          <label>Title<input name="title" maxlength="180" required value="<%= h(@task.title) %>"><%= errors_for(@task, :title) %></label>
          <label>Due date<input name="due_on" type="date" value="<%= @task.due_on&.iso8601 %>"><%= errors_for(@task, :due_on) %></label>
        </div>
        <div class="form-grid">
          <label>State<select name="state"><%= task_state_options(@task.state) %></select><%= errors_for(@task, :state) %></label>
          <label>Priority<select name="priority"><%= task_priority_options(@task.priority) %></select><%= errors_for(@task, :priority) %></label>
        </div>
        <label>Description<textarea name="description" maxlength="5000" placeholder="Add context, acceptance criteria, or a handoff note."><%= h(@task.description) %></textarea><%= errors_for(@task, :description) %></label>
        <div class="form-actions"><button class="button button-primary" type="submit">Save task</button><a class="nav-link" href="/projects/<%= @project.id %>">Cancel</a></div>
      </form>
    HTML
  end

  template :activity do
    <<~HTML
      <header>
        <a class="brand" href="/">dashboard<i>ia</i></a>
        <nav><a class="nav-link" href="/projects">Projects</a><a class="nav-link" href="/tasks">My work</a><a class="nav-link" href="/api/v1/activity">JSON API</a></nav>
      </header>
      <h1>Workspace activity</h1>
      <p class="lead">An audit trail of project and task changes, persisted alongside the work itself.</p>
      <% if @activity_events.any? %>
        <section class="activity-list">
          <% @activity_events.each do |event| %>
            <article class="activity">
              <div class="task-top"><p><%= h(event.message) %></p><span class="tag"><%= h(event_label(event)) %></span></div>
              <small><a href="/projects/<%= event.project_id %>"><%= h(event.project.name) %></a><% if event.task %> · <a href="/tasks/<%= event.task_id %>/edit"><%= h(event.task.title) %></a><% end %> · <%= event.created_at.strftime("%b %-d, %Y at %H:%M") %></small>
            </article>
          <% end %>
        </section>
      <% else %>
        <div class="empty">No activity has been recorded yet. Create a project or add a task to begin.</div>
      <% end %>
    HTML
  end

  template :not_found do
    <<~HTML
      <header><a class="brand" href="/">dashboard<i>ia</i></a><nav><a class="nav-link" href="/projects">Projects</a><a class="nav-link" href="/tasks">My work</a></nav></header>
      <h1>That page is not available.</h1>
      <p class="lead">Return to the <a href="/">workspace overview</a> or inspect the <a href="/health">service health</a>.</p>
    HTML
  end
end

DashboardiaApp.run! if $PROGRAM_NAME == __FILE__