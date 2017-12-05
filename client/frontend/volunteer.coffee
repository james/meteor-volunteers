import SimpleSchema from 'simpl-schema'

Template.addVolunteerForm.onCreated () ->
  template = this
  template.subscribe('FormBuilder.dynamicForms')
  share.templateSub(template,"volunteerForm")

# XXX this should be modified to allow the admin to edit the data of any
# user and not only display Meteor.userId() / the current user
Template.addVolunteerForm.helpers
  'form': () ->
    form = share.form.get()
    if form then {
      collection: form
      insert:
        label: TAPi18n.__("create_volunteer_profile")
      update:
        label: TAPi18n.__("update_volunteer_profile")
    }
  'data': () -> share.VolunteerForm.findOne({userId: Meteor.userId()})

addLocalShiftsCollection = (collection,template,type,filter = {},limit = 0) ->
  collection.find(filter,{limit: limit}).forEach((job) ->
    orgUnit = share.getOrgUnit(job.parentId)
    team = orgUnit.lowest
    users = []
    signupsSub = share.templateSub(template,"signups.byShift",job._id)
    if signupsSub.ready()
      signupCollection = share.signupCollections[type]
      users = signupCollection.find(
        {shiftId: job._id, status: {$in: ["confirmed"]}}
      ).map((s) -> s.userId)
      signup = signupCollection.findOne({shiftId: job._id, userId: Meteor.userId()})
      sel =
        teamId: team._id
        shiftId: job._id
      mod =
        type: type
        teamName: team.name
        departmentName: orgUnit?.department?.name
        divisionName: orgUnit?.division?.name
        title: job.title
        description: job.description
        status: if signup then signup.status else null
        canBail: signup? and signup.status != 'bailed'
        policy: job.policy
        tags: team.tags
        users: users
      if type == 'shift'
        _.extend(mod,
          start: job.start
          end: job.end
          startTime: job.startTime
          endTime: job.endTime)
      if type == 'task'
        _.extend(mod,
          dueDate : job.dueDate
          estimatedTime: job.estimatedTime)
      if type == 'lead'
        # I'm not sure if the below is used anywhere - Rich
        _.extend(mod,
          isChecked: if Meteor.userId() in users then "checked" else null)
      template.ShiftTaskLocal.upsert(sel,{$set: mod})
    )

Template.volunteerShiftsForm.onCreated () ->
  template = this
  template.searchQuery = new ReactiveDict()
  template.ShiftTaskLocal = new Mongo.Collection(null)
  template.sel = new ReactiveVar({})

  template.searchQuery.set('range',[])
  template.searchQuery.set('days',[])
  template.searchQuery.set('period',[])
  template.searchQuery.set('tags',[])
  template.searchQuery.set('types',[])
  template.searchQuery.set('areas',[])
  template.searchQuery.set('limit',10)

  template.autorun () ->
    filter = makeFilter(template.searchQuery)
    limit = template.searchQuery.get('limit')
    share.templateSub(template,"division")
    share.templateSub(template,"department")
    sub = share.templateSub(template,"allDuties", filter, limit)

    if sub.ready()
      addLocalShiftsCollection(share.TeamShifts,template,'shift',filter,limit)
      addLocalShiftsCollection(share.TeamTasks,template,'task',filter,limit)
      addLocalShiftsCollection(share.Lead,template,'lead',filter,limit)
    template.sel.set(filter)

Template.volunteerShiftsForm.helpers
  'searchQuery': () -> Template.instance().searchQuery
  'loadMore': () ->
    template = Template.instance()
    shifts = template.ShiftTaskLocal.find()
    limit = template.searchQuery.get("limit")
    shifts.count() <= limit
  'allShiftsTasks': () ->
    template = Template.instance()
    sort = {sort: {isChecked:-1, start: -1, dueDate:-1}}
    sel = template.sel.get()
    template.ShiftTaskLocal.find(sel,sort)

Template.volunteerShiftsForm.events
  'click [data-action="loadMore"]': ( event, template ) ->
    limit = template.searchQuery.get("limit")
    template.searchQuery.set("limit",limit+10)

Template.volunteerUserShifts.onCreated () ->
  template = this
  template.ShiftTaskLocal = new Mongo.Collection(null)

  template.autorun () ->
    sub = share.templateSub(template,"allDuties.byUser")

    if sub.ready()
      addLocalShiftsCollection(share.TeamShifts,template,'shift',{},100)
      addLocalShiftsCollection(share.TeamTasks,template,'task',{},100)
      addLocalShiftsCollection(share.Lead,template,'lead',{},100)

Template.volunteerUserShifts.helpers
  'allShifts': () ->
    template = Template.instance()
    sort = {sort: {start: -1, dueDate:-1}}
    template.ShiftTaskLocal.find({type: "shift"},sort)
  'allTasks': () ->
    template = Template.instance()
    sort = {sort: {start: -1, dueDate:-1}}
    template.ShiftTaskLocal.find({type: "task"},sort)

Template.volunteersTeamView.onCreated () ->
  template = this
  template.ShiftTaskLocal = new Mongo.Collection(null)
  template.teamId = template.data._id

  template.autorun () ->
    template.sub = share.templateSub(template,"allDuties.byTeam", template.teamId)
    if template.sub.ready()
      addLocalShiftsCollection(share.TeamShifts,template,'shift',{},100)
      addLocalShiftsCollection(share.TeamTasks,template,'task',{},100)
      addLocalShiftsCollection(share.Lead,template,'lead',{},100)

Template.volunteersTeamView.helpers
  'team': () ->
    template = Template.instance()
    if template.sub.ready()
      share.Team.findOne(template.teamId)
  'division': () ->
    template = Template.instance()
    if template.sub.ready()
      team = share.Team.findOne(template.teamId)
      department = share.Department.findOne(team.parentId)
      share.Division.findOne(department.parentId)
  'department': () ->
    template = Template.instance()
    if template.sub.ready()
      team = share.Team.findOne(template.teamId)
      share.Department.findOne(team.parentId)
  'allShiftsTasks': () ->
    template = Template.instance()
    template.ShiftTaskLocal.find()
  canEditTeam: () =>
    teamId = Template.instance().data._id
    # console.log(teamId, Roles.userIsInRole(Meteor.userId(), ['manager', teamId], share.eventName))
    Roles.userIsInRole(Meteor.userId(), ['manager', teamId], share.eventName)
  'teamEditEventName': () -> 'teamEdit-'+share.eventName1.get()
