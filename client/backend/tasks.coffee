Template.addTeamTasks.onCreated () ->
  template = this
  template.subscribe('Volunteers.users')
  template.subscribe('Volunteers.teamTasks')

Template.addTeamTasks.helpers
  form: () -> { collection: share.TeamTasks }

Template.tasksTable.onCreated () ->
  template = this
  template.subscribe('Volunteers.users')
  if template.data?._id
    template.subscribe('Volunteers.teamTasks.backend',template.data._id)

Template.tasksTable.helpers
  'allTasks': () -> share.TeamTasks.find()

AutoForm.addHooks ['UpdateTeamTasksFormId'], #,'InsertTeamTasksFormId'],
  docToForm: (doc) ->
    doc.dueDate = moment(doc.dueDate).format("DD-MM-YYYY HH:mm")
    return doc

AutoForm.addHooks ['InsertTeamTasksFormId','UpdateTeamTasksFormId'],
  onSuccess: (formType, result) ->
    this.template.data.var.set({add: false, teamId: result.teamId})
