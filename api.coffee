
share.form = new ReactiveVar(share.VolunteerForm)
periods =
  'night': {start:0,end:4},
  'dawn': {start:4,end:8},
  'morning': {start:8,end:12},
  'afternoon': {start:12,end:16},
  'dusk': {start:16,end:20},
  'evening': {start:20,end:24}
share.periods = new ReactiveVar(periods)


initAuthorization = (eventName) ->
  # is the given user manager or admin ?
  share.isManager = (userId = Meteor.userId()) ->
    Roles.userIsInRole(userId, [ 'manager', 'admin' ], eventName)
  # is the given is Manager, or Lead of one of the unitIdList
  share.isManagerOrLead = (userId, unitIdList) ->
    if share.isManager(userId) then return true
    else if userId == Meteor.userId()
      Roles.userIsInRole(userId, unitIdList, eventName)
    else return false
  # is the given user a Lead of any team or dept ?
  share.isLead = (userId = Meteor.userId()) ->
    (Roles.getRolesForUser(userId, eventName).length > 0)

saveVolunteerForm = (eventName,data) ->
  Meteor.call('FormBuilder.dynamicForms.upsert',{name: "VolunteerForm"}, data)
  share.extendVolunteerForm({form: data})

class VolunteersClass
  constructor: (@eventName) ->
    share.initCollections(@eventName)
    share.initRouters(@eventName)
    share.initMethods(@eventName)
    if Meteor.isServer
      share.initServerMethods(@eventName)
    initAuthorization(@eventName)
    if Meteor.isServer
      share.initPublications(@eventName)
    @Schemas = share.Schemas
    @Collections =
      VolunteerForm: share.VolunteerForm
      Team: share.Team
      Division: share.Division
      Department: share.Department
      TeamShifts: share.TeamShifts
      TeamTasks: share.TeamTasks
      Projects: share.Projects
      Lead: share.Lead
      ShiftSignups: share.ShiftSignups
      ProjectSignups: share.ProjectSignups
      TaskSignups: share.TaskSignups
      LeadSignups: share.LeadSignups
      UnitAggregation: share.UnitAggregation
    @components = {}
    if Meteor.isClient
      BookedTableModule = require('./client/components/volunteers/BookedTable.jsx')
      @components = {BookedTableContainer: BookedTableModule.BookedTableContainer}
  setPeriods: (periods) -> share.periods.set(periods)
  setTimeZone: (timezone) -> share.timezone.set(timezone)
  setUserForm: (data) -> saveVolunteerForm(@eventName,data)
  isManagerOrLead: (userId,unitId) -> share.isManagerOrLead(userId,unitId)
  isManager: () -> share.isManager()
  isLead: () -> share.isLead()
  teamStats: (id) -> share.TeamStats(id)
  deptStats: (id) -> share.DepartmentStats(id)
  getSkillsList: share.getSkillsList
  getQuirksList: share.getQuirksList
