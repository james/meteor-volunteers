import { ReactiveVar } from 'meteor/reactive-var'

import Moment from 'moment'
import 'moment-timezone'
import { extendMoment } from 'moment-range'

const share = __coffeescriptShare

const moment = extendMoment(Moment)
moment.tz.setDefault(share.timezone.get())

Template.teamSignupsList.bindI18nNamespace('abate:volunteers')
Template.teamSignupsList.onCreated(function onCreated() {
  const template = this
  const teamId = template.data._id
  template.signups = new ReactiveVar([])
  share.templateSub(template, 'ShiftSignups.byTeam', teamId)
  share.templateSub(template, 'TaskSignups.byTeam', teamId)
  share.templateSub(template, 'ProjectSignups.byTeam', teamId)
  share.templateSub(template, 'LeadSignups.byTeam', template.teamId)
  template.autorun(() => {
    if (template.subscriptionsReady()) {
      const shifts = share.ShiftSignups.find({ parentId: teamId, status: 'pending' }, { sort: { createdAt: -1 } })
        .map(signup => ({
          ...signup,
          type: 'shift',
          duty: share.TeamShifts.findOne(signup.shiftId),
        }))
      const tasks = share.TaskSignups.find({ parentId: teamId, status: 'pending' }, { sort: { createdAt: -1 } })
        .map(signup => ({
          ...signup,
          type: 'task',
          duty: share.TeamTasks.findOne(signup.shiftId),
        }))
      const projects = share.ProjectSignups.find({ parentId: teamId, status: 'pending' }, { sort: { createdAt: -1 } })
        .map(signup => ({
          ...signup,
          type: 'project',
          duty: share.Projects.findOne(signup.shiftId),
        }))
      const leads = share.LeadSignups.find({ parentId: teamId, status: 'pending' }, { sort: { createdAt: -1 } })
        .map(signup => ({
          ...signup,
          type: 'lead',
          duty: share.Lead.findOne(signup.shiftId),
        }))
      const signups = [
        ...shifts,
        ...tasks,
        ...projects,
        ...leads,
      ].sort((a, b) => a.createdAt && b.createdAt && a.createdAt.getTime() - b.createdAt.getTime())

      share.templateSub(template, 'volunteerForm.list', signups.map(signup => signup.userId))
      template.signups.set(signups)
    }
  })
})

Template.teamSignupsList.helpers({
  allSignups() {
    return Template.instance().signups.get()
  },
  createdAgo(date) {
    return moment(date).fromNow()
  },
})

Template.teamSignupsList.events({
  'click [data-action="approve"]': function e(event, template) {
    const type = template.$(event.target).data('type')
    const signupId = template.$(event.target).data('signup')
    if (type === 'lead') {
      share.meteorCall(`${type}Signups.confirm`, signupId)
    } else {
      const signup = { _id: signupId, modifier: { $set: { status: 'confirmed' } } }
      share.meteorCall(`${type}Signups.update`, signup)
    }
  },
  'click [data-action="refuse"]': function e(event, template) {
    const type = template.$(event.target).data('type')
    const signupId = template.$(event.target).data('signup')
    if (type === 'lead') {
      share.meteorCall(`${type}Signups.refuse`, signupId)
    } else {
      const signup = { _id: signupId, modifier: { $set: { status: 'refused' } } }
      share.meteorCall(`${type}Signups.update`, signup)
    }
  },
  'click [data-action="user-info"]': function e(event, template) {
    const userId = template.$(event.currentTarget).data('id')
    const form = share.VolunteerForm.findOne({ userId })
    const user = Meteor.users.findOne(userId)
    const userform = { formName: 'VolunteerForm', form, user }
    // Lifted straight from NoInfo view, should be replaced by something better
    AutoFormComponents.ModalShowWithTemplate(
      'formBuilderDisplay',
      userform, 'User Form', 'lg',
    )
  },
})

Template.departmentSignupsList.bindI18nNamespace('abate:volunteers')
Template.departmentSignupsList.onCreated(function onCreated() {
  const template = this
  template.departmentId = this.data._id
  share.templateSub(template, 'LeadSignups.byDepartment', template.departmentId)
})

Template.departmentSignupsList.helpers({
  allSignups: () => {
    const departmentId = Template.instance().departmentId
    const teamIds = share.Team.find({ parentId: departmentId }).map(t => t._id)
    const leads = share.LeadSignups.find({ parentId: { $in: teamIds }, status: 'pending' }, { sort: { createdAt: -1 } }).map(signup => ({
      ...signup,
      type: 'lead',
      unit: share.Team.findOne(signup.parentId),
      duty: share.Lead.findOne(signup.shiftId),
    })).sort((a, b) => a.createdAt && b.createdAt && a.createdAt.getTime() - b.createdAt.getTime())
    return leads
  },
})

Template.departmentSignupsList.events({
  'click [data-action="approve"]': function e(event) {
    const signupId = $(event.target).data('signup')
    share.meteorCall('leadSignups.confirm', signupId)
  },
  'click [data-action="refuse"]': function e(event) {
    const signupId = $(event.target).data('signup')
    share.meteorCall('leadSignups.refuse', signupId)
  },
})

Template.managerSignupsList.bindI18nNamespace('abate:volunteers')
Template.managerSignupsList.onCreated(function onCreated() {
  const template = this
  share.templateSub(template, 'LeadSignups.Manager')
})

Template.managerSignupsList.helpers({
  allSignups: () => {
    const divisionIds = share.Division.find().map(t => t._id)
    const deptIds = share.Department.find({ parentId: { $in: divisionIds } }).map(t => t._id)
    const teamIds = share.Team.find({ parentId: { $in: deptIds } }).map(t => t._id)
    const leads = share.LeadSignups.find({
      parentId: { $in: teamIds.concat(deptIds).concat(divisionIds) },
      status: 'pending',
    }, { sort: { createdAt: -1 } }).map(signup => ({
      ...signup,
      type: 'lead',
      // XXX this should be either team, dept or division
      unit: share.Department.findOne(signup.parentId),
      duty: share.Lead.findOne(signup.shiftId),
    })).sort((a, b) => a.createdAt && b.createdAt && a.createdAt.getTime() - b.createdAt.getTime())
    return leads
  },
})
