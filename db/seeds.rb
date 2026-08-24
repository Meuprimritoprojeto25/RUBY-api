# This file is safe to invoke repeatedly. It deliberately uses validated
# Active Record writes rather than inserting rows directly.
module DemoData
  module_function

  def load!
    launch = Project.find_or_initialize_by(code: "product-launch")
    launch.assign_attributes(
      name: "Product launch",
      description: "Coordinate the public release of the new planning experience.",
      status: "active"
    )
    launch.save!
    activity_for(launch, "project_created", "Demo project Product launch is ready.") if launch.activity_events.empty?

    operations = Project.find_or_initialize_by(code: "operations")
    operations.assign_attributes(
      name: "Operations",
      description: "Recurring work that keeps the platform reliable.",
      status: "active"
    )
    operations.save!
    activity_for(operations, "project_created", "Demo project Operations is ready.") if operations.activity_events.empty?

    upsert_task(
      launch,
      "Publish release notes",
      description: "Prepare a concise customer-facing summary of the release.",
      state: "in_progress",
      priority: "high",
      due_on: Date.current + 3
    )
    upsert_task(
      launch,
      "Validate onboarding flow",
      description: "Walk through the first-run journey on desktop and mobile.",
      state: "todo",
      priority: "medium",
      due_on: Date.current + 5
    )
    upsert_task(
      operations,
      "Review service health",
      description: "Review error rate, latency, and capacity trends.",
      state: "done",
      priority: "medium",
      due_on: Date.current
    )
  end

  def upsert_task(project, title, attributes)
    task = project.tasks.find_or_initialize_by(title: title)
    new_task = task.new_record?
    task.assign_attributes(attributes)
    task.save!
    activity_for(project, "task_created", "Added task “#{task.title}”.", task: task) if new_task
  end

  def activity_for(project, event_type, message, task: nil)
    project.activity_events.create!(event_type: event_type, message: message, task: task)
  end
  private_class_method :upsert_task, :activity_for
end