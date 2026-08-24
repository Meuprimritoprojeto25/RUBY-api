require "sinatra/base"
require "json"
require "date"
require_relative "config/environment"

class DashboardiaApp < Sinatra::Base
  configure do
    set :root, ROOT.to_s
    set :environment, ENV.fetch("RACK_ENV", "development").to_sym
    set :show_exceptions, false
    set :raise_errors, false
  end

  use Rack::Deflater
  use Rack::Protection, except: :path_traversal

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
    erb :dashboard
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
    json_response({ data: project_payload(project) }, 201)
  end

  get "/api/v1/projects/:id" do
    json_response(data: project_payload(find_project, include_tasks: true))
  end

  patch "/api/v1/projects/:id" do
    project = find_project
    project.update!(project_attributes(json_body))
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
    json_response({ data: task_payload(task) }, 201)
  end

  get "/api/v1/tasks/:id" do
    json_response(data: task_payload(find_task))
  end

  patch "/api/v1/tasks/:id" do
    task = find_task
    task.update!(task_attributes(json_body))
    json_response(data: task_payload(task))
  end

  delete "/api/v1/tasks/:id" do
    find_task.destroy!
    status 204
  end

  not_found do
    if request.path_info.start_with?("/api/", "/health")
      json_response({ error: { code: "not_found", message: "Route not found" } }, 404)
    end

    erb :not_found
  end

  error ActiveRecord::RecordNotFound do
    json_response({ error: { code: "not_found", message: "Record not found" } }, 404)
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

    def task_attributes(body)
      attributes = permitted_attributes(body, "title", "description", "state", "priority", "due_on")
      attributes["due_on"] = Date.iso8601(attributes["due_on"]) if attributes["due_on"].present?
      attributes
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

    def completion_rate
      total = Task.count
      return 0 if total.zero?

      ((Task.where(state: "done").count.to_f / total) * 100).round
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
            :root { color-scheme: dark; --bg:#0b1020; --panel:#151d33; --muted:#91a0bd; --line:#293653; --text:#f3f6ff; --accent:#7c9cff; --green:#47d7a7; --amber:#ffc76b; }
            * { box-sizing:border-box; } body { margin:0; font-family:Inter,ui-sans-serif,system-ui,-apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif; background:radial-gradient(circle at 90% 0%,#202c57 0,var(--bg) 38rem); color:var(--text); }
            main { max-width:1120px; margin:auto; padding:46px 24px 64px; } header { display:flex; justify-content:space-between; align-items:center; gap:16px; margin-bottom:38px; } .brand { font-weight:800; letter-spacing:-.04em; font-size:22px; } .brand i { color:var(--accent); font-style:normal; } .api { color:var(--muted); border:1px solid var(--line); padding:8px 12px; border-radius:9px; font-size:13px; } h1 { font-size:clamp(30px,5vw,48px); max-width:650px; margin:0 0 12px; letter-spacing:-.055em; line-height:1.05; } .lead { color:var(--muted); max-width:610px; line-height:1.55; margin:0 0 30px; } .grid { display:grid; grid-template-columns:repeat(4,1fr); gap:14px; margin-bottom:28px; } .metric,.project { border:1px solid var(--line); background:rgba(21,29,51,.86); border-radius:15px; } .metric { padding:18px; } .metric span { color:var(--muted); display:block; font-size:13px; margin-bottom:10px; } .metric strong { font-size:29px; letter-spacing:-.04em; } .section-head { display:flex; justify-content:space-between; align-items:center; margin:25px 0 12px; } h2 { margin:0; font-size:18px; } a { color:var(--accent); } .projects { display:grid; grid-template-columns:repeat(2,1fr); gap:14px; } .project { padding:20px; } .project-top { display:flex; justify-content:space-between; gap:10px; } .project h3 { margin:0; font-size:16px; } .project p { color:var(--muted); font-size:14px; line-height:1.45; min-height:40px; } .tag { font-size:12px; padding:4px 8px; border-radius:20px; background:#202c4b; color:#bdc9eb; text-transform:capitalize; } .task-line { border-top:1px solid var(--line); padding-top:12px; font-size:13px; color:#c9d3ed; display:flex; justify-content:space-between; } .empty { padding:34px; border:1px dashed var(--line); color:var(--muted); border-radius:15px; text-align:center; } @media(max-width:720px) { .grid { grid-template-columns:repeat(2,1fr); } .projects { grid-template-columns:1fr; } } @media(max-width:420px) { .grid { grid-template-columns:1fr; } header { align-items:flex-start; flex-direction:column; } }
          </style>
        </head>
        <body><main><%= yield %></main></body>
      </html>
    HTML
  end

  template :dashboard do
    <<~HTML
      <header><div class="brand">dashboard<i>ia</i></div><div class="api">API ready · <a href="/health">health</a></div></header>
      <h1>A clear view of work that moves the business forward.</h1>
      <p class="lead">A resilient Ruby API with persistent projects and tasks. Use the dashboard for a live overview or connect directly to the versioned JSON API.</p>
      <section class="grid">
        <div class="metric"><span>Projects</span><strong><%= @total_projects %></strong></div>
        <div class="metric"><span>All tasks</span><strong><%= @total_tasks %></strong></div>
        <div class="metric"><span>In progress</span><strong><%= @in_progress_tasks %></strong></div>
        <div class="metric"><span>Completed</span><strong><%= @completed_tasks %></strong></div>
      </section>
      <div class="section-head"><h2>Recent projects</h2><a href="/api/v1/projects">View API response →</a></div>
      <% if @projects.any? %>
        <section class="projects">
          <% @projects.each do |project| %>
            <article class="project">
              <div class="project-top"><h3><%= Rack::Utils.escape_html(project.name) %></h3><span class="tag"><%= project.status %></span></div>
              <p><%= Rack::Utils.escape_html(project.description) %></p>
              <div class="task-line"><span><%= project.tasks.size %> task<%= project.tasks.size == 1 ? "" : "s" %></span><span><%= project.code %></span></div>
            </article>
          <% end %>
        </section>
      <% else %>
        <div class="empty">Your workspace is ready. Start by creating a project with <code>POST /api/v1/projects</code>, or enable <code>DASHBOARDIA_DEMO_MODE=true</code> for sample data.</div>
      <% end %>
    HTML
  end

  template :not_found do
    <<~HTML
      <header><div class="brand">dashboard<i>ia</i></div></header>
      <h1>That page is not available.</h1>
      <p class="lead">Return to the <a href="/">workspace overview</a> or inspect the <a href="/health">service health</a>.</p>
    HTML
  end
end

DashboardiaApp.run! if $PROGRAM_NAME == __FILE__