/* global __coffeescriptShare */
import { Meteor } from 'meteor/meteor'
import { AutoFormComponents } from 'meteor/abate:autoform-components'
import { Bert } from 'meteor/themeteorchef:bert'
import { t } from '../components/common/i18n'

const share = __coffeescriptShare

export const bailCall = ({
  type,
  parentId,
  _id,
  shiftId = _id,
  userId = Meteor.userId(),
}) => () => {
  // I18N
  if (window.confirm('Are you sure you want to cancel this shift?')) {
    share.meteorCall(`${type}Signups.bail`, { parentId, shiftId, userId })
  }
}

const applyErrorCallback = (err) => {
  if (!err) return
  if (err.error === 409 && err.reason === 'Double Booking') {
    Bert.alert({
      hideDelay: 6500,
      title: t('double_booking'),
      message: t('double_booking_msg'),
      type: 'warning',
      style: 'growl-top-right',
    })
  } else if (err.error === 409) {
    Bert.alert({
      hideDelay: 6500,
      title: t('shift_full'),
      message: t('shift_full_msg'),
      type: 'warning',
      style: 'growl-top-right',
    })
  } else {
    Bert.alert({
      hideDelay: 6500,
      title: t('error'),
      message: err.reason,
      type: 'danger',
      style: 'growl-top-right',
    })
  }
}

export const applyCall = ({
  _id,
  shiftId = _id,
  type,
  parentId,
  userId = Meteor.userId(),
}) => () => {
  const signup = { parentId, shiftId, userId }
  if (type === 'project') {
    const project = share.Projects.findOne(shiftId)
    AutoFormComponents.ModalShowWithTemplate('projectSignupForm', { signup, project }, project.title)
  } else {
    share.meteorCall(`${type}Signups.insert`, signup, applyErrorCallback)
  }
}
