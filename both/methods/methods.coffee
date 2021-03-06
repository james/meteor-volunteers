import SimpleSchema from 'simpl-schema'
import Moment from 'moment-timezone'
import { extendMoment } from 'moment-range'

moment = extendMoment(Moment)

throwError = (error, reason, details) ->
  error = new (Meteor.Error)(error, reason, details)
  if Meteor.isClient
    return error
  else if Meteor.isServer
    throw error
  return

share.setMethodTimezone = (timezone) ->
  moment.tz.setDefault(timezone)

share.initMethods = (eventName) ->

  # Generic function to create insert,update,remove methods for groups within
  # the organisation, e.g. teams
  createOrgUnitMethod = (collection, type) ->
    collectionName = collection._name
    switch type
      when "remove"
        Meteor.methods "#{collectionName}.remove": (Id) ->
          console.log ["#{collectionName}.remove", Id]
          check(Id,String)
          if share.isManagerOrLead(Meteor.userId(),[Id])
            if Meteor.isServer then Roles.deleteRole(Id)
            collection.remove(Id)
            # delete all shifts and signups associated to this team
            # XXX if this is a dept, we should remove also all teams
            for k,collection of share.dutiesCollections
              do ->
                collection.remove({parentId: Id})
            for k,collection of share.signupCollections
              do ->
                collection.update({shiftId: Id},{$set: {status: 'cancelled'}})
          else
            return throwError(403, 'Insufficient Permission')
      when "insert"
        Meteor.methods "#{collectionName}.insert": (doc) ->
          console.log ["#{collectionName}.insert",doc]
          collection.simpleSchema().validate(doc)
          allowedRoles = [ 'manager' ]
          if doc.parentId != 'TopEntity'
            parentRole = doc.parentId
            allowedRoles.push(parentRole)
          if share.isManagerOrLead(Meteor.userId(),allowedRoles)
            collection.insert(doc, (err,newDocId) ->
              unless err
                if Meteor.isServer
                  Roles.createRole(newDocId, {unlessExists: true})
                  Roles.addRolesToParent(newDocId, parentRole) if parentRole?
              else
                return throwError(501, 'Cannot Insert')
              )
          else
            return throwError(403, 'Insufficient Permission')
      when "update"
        Meteor.methods "#{collectionName}.update": (doc) ->
          console.log ["#{collectionName}.update",doc._id,doc.modifier]
          collection.simpleSchema().validate(doc.modifier,{modifier:true})
          if share.isManagerOrLead(Meteor.userId(),[doc._id])
            oldDoc = collection.findOne(doc._id)
            collection.update(doc._id,doc.modifier, (err,res) ->
              unless err
                if Meteor.isServer
                  if oldDoc.parentId != doc.modifier.$set.parentId
                    Roles.removeRolesFromParent(doc._id, oldDoc.parentId)
                    Roles.addRolesToParent(doc._id, doc.modifier.$set.parentId)
              else
                return throwError(501, 'Cannot Update')
              )
          else
            return throwError(403, 'Insufficient Permission')
      else
        console.warn "type #{type} for #{collectionName} ERROR"

  # Generic function to create insert,update,remove methods.
  # Security check : user must be manager
  createDutiesMethod = (collection,type,kind) ->
    collectionName = collection._name
    switch type
      when "remove"
        Meteor.methods "#{collectionName}.remove": (Id) ->
          console.log ["#{collectionName}.remove", Id]
          check(Id,String)
          doc = collection.findOne(Id)
          if share.isManagerOrLead(Meteor.userId(),[doc.parentId])
            collection.remove(Id)
            for k,scollection of share.signupCollections
              do ->
                scollection.update({shiftId: Id},{$set: {status: 'cancelled'}})
          else
            throwError(403, 'Insufficient Permission')
      when "insert"
        Meteor.methods "#{collectionName}.insert": (doc) ->
          console.log ["#{collectionName}.insert",doc]
          collection.simpleSchema().validate(doc)
          if share.isManagerOrLead(Meteor.userId(),[doc.parentId])
            collection.insert(doc)
          else
            throwError(403, 'Insufficient Permission')
      when "update"
        Meteor.methods "#{collectionName}.update": (doc) ->
          console.log ["#{collectionName}.update",doc._id,doc.modifier]
          collection.simpleSchema().validate(doc.modifier,{modifier:true})
          olddoc = collection.findOne(doc._id)
          if share.isManagerOrLead(Meteor.userId(),[olddoc.parentId])
            collection.update(doc._id,doc.modifier)
          else
            throwError(403, 'Insufficient Permission')
      else
        console.warn "type #{type} for #{collectionName} ERROR"

  for type in ["remove","insert","update"]
    do ->
      for kind,collection of share.dutiesCollections
        do ->
          createDutiesMethod(collection,type, kind)

  for type in ["remove","insert","update"]
    do ->
      for kind,collection of share.orgUnitCollections
        do ->
          createOrgUnitMethod(collection, type, kind)

  prefix = "#{eventName}.Volunteers"

  Meteor.methods "#{prefix}.teamShifts.group.remove": (group) ->
    console.log ["#{prefix}.teamShifts.group.remove", group]
    check(group, {groupId: String, parentId: String})
    if share.isManagerOrLead(Meteor.userId(),[group.parentId])
      share.TeamShifts.remove(group)
    else
      return throwError(403, 'Insufficient Permission')

  groupSchema = new SimpleSchema(share.Schemas.Common)
  groupSchema.extend(share.SubSchemas.DayDates)
  groupSchema.extend({
    shifts: { type: Array , minCount: 1 }
    'shifts.$': {
      type: share.SubSchemas.Bounds.extend({
        startTime: String,
        endTime: String,
        rotaId: { type: Number, optional: true } })
      optional: true
    }
    oldshifts: {type: Array, optional: true}
    'oldshifts.$': {
      type: share.SubSchemas.Bounds.extend({
        startTime: String,
        endTime: String,
        rotaId: Number })
    }
  })

  Meteor.methods "#{prefix}.teamShifts.group.update": (doc) ->
    console.log ["#{prefix}.teamShifts.group.update", doc]
    doc.modifier.$set.shifts = doc.modifier.$set.shifts.filter(Boolean)
    groupSchema.validate(doc.modifier,{modifier: true})
    { parentId, groupId } = doc.modifier.$set
    if share.isManagerOrLead(Meteor.userId(),[parentId])
      genericModifier = _.omit(doc.modifier.$set,'shifts','start','end',)
      { start, end, shifts , oldshifts } = doc.modifier.$set

      # Remove shifts outside of the altered rota dates
      # TODO When not using autoform extract this and add a check with user about deleting shifts
      [startHour, startMin] = shifts[0].startTime.split(':')
      [endHour, endMin] = shifts[shifts.length - 1].endTime.split(':')
      firstShiftStart = moment(start).hour(startHour).minute(startMin)
      lastShiftEnd = moment(end).hour(endHour).minute(endMin)
      share.TeamShifts.remove({ groupId, parentId, $or: [
        { start: { $lt: firstShiftStart.toDate() }},
        { end: { $gt: lastShiftEnd.toDate() }}, ]
      })

      oldshifts = oldshifts.filter(Boolean)
      shifts = shifts.filter(Boolean).map((s,idx) ->
        _.extend(s,{oldRotaId: s.rotaId, rotaId:idx}))
      Array.from(moment.range(start, end).by('days')).forEach((day) ->
        # Do we need to do this per day or can we get a country code instead of a offset?
        timezone = moment(day).format('ZZ')
        day.utcOffset(timezone)
        sel = {
          parentId, groupId,
          start: {
            $gte: moment(day).startOf('day').toDate(),
            $lt:  moment(day).add(1,'day').startOf('day').toDate() }}
        # remove old shifts
        oldshifts.forEach((shiftSpecifics) ->
          { rotaId, startTime, endTime, min, max } = shiftSpecifics
          unless _.find(shifts,(r) -> r.oldRotaId == rotaId)
            console.log "remove shift for #{moment(day).format("DD-MM-YYYY")} #{startTime}, #{endTime}, #{rotaId}"
            share.TeamShifts.remove(_.extend(sel,{rotaId}))
        )
        # update old shifts and add new shift of a given day

        console.log "looking at ",moment(day).format("DD-MM-YYYY")
        shifts.forEach((shiftSpecifics,idx) ->
          { oldRotaId, rotaId, startTime, endTime, min, max } = shiftSpecifics
          sel.rotaId = oldRotaId
          [startHour, startMin] = startTime.split(':')
          [endHour, endMin] = endTime.split(':')
          shiftStart = moment(day).hour(startHour).minute(startMin).utcOffset(timezone, true)
          shiftEnd = moment(day).hour(endHour).minute(endMin).utcOffset(timezone, true)
          if shiftEnd.isBefore(shiftStart) then shiftEnd.add(1, 'day')
          modifier = Object.assign(genericModifier, {
            start: shiftStart.toDate(),
            end: shiftEnd.toDate(),
            min, max, rotaId})

          if oldRotaId?
            console.log "upsert shift for #{moment(day).format("DD-MM-YYYY")} #{startTime}, #{endTime}, #{oldRotaId} -> #{rotaId}"
            share.TeamShifts.upsert(sel, { $set: modifier })
          else
            console.log "insert shift for #{moment(day).format("DD-MM-YYYY")} #{startTime}, #{endTime}, #{oldRotaId} -> #{rotaId}"
            share.TeamShifts.insert(modifier)
        )
      )
    else
      throwError(403, 'Insufficient Permission')

  Meteor.methods "#{prefix}.teamShifts.group.insert": (group) ->
    console.log ["#{prefix}.teamShifts.group.insert", group]
    groupSchema.validate(group)
    {shifts, start, end, parentId} = group
    details = _.omit(group, 'shifts', 'start', 'end')
    if share.isManagerOrLead(Meteor.userId(),[parentId])
      groupId = Random.id()
      _.flatten(Array.from(moment.range(start, end).by('days')).map((day) ->
        shifts.map((shiftSpecifics,rotaId) ->
          [startHour, startMin] = shiftSpecifics.startTime.split(':')
          [endHour, endMin] = shiftSpecifics.endTime.split(':')
          # this is the global timezone known by moment that we use to offset
          # the date given by the client to store it in the database as a js Date()
          # js Date() is timezone agnostic and always stored in UTC.
          # Using the method Date().toString() the local timezone (set on the server)
          # is used to print the date.
          timezone = moment(day).format('ZZ')
          day.utcOffset(timezone)
          shiftStart = moment(day).hour(startHour).minute(startMin).utcOffset(timezone, true)
          shiftEnd = moment(day).hour(endHour).minute(endMin).utcOffset(timezone, true)
          # Deal with day wrap-around
          if shiftEnd.isBefore(shiftStart)
            shiftEnd.add(1, 'day')
          return _.extend({
            min: shiftSpecifics.min,
            max: shiftSpecifics.max,
            start: shiftStart.toDate(),
            end: shiftEnd.toDate(),
            groupId,
            rotaId
          }, details))
        ), true).forEach((constructedShift) ->
          share.TeamShifts.insert(constructedShift)
        )
    else
      throwError(403, 'Insufficient Permission')

  Meteor.methods "#{prefix}.volunteerForm.remove": (formId) ->
    console.log ["#{prefix}.volunteerForm.remove",formId]
    check(formId,String)
    if share.isManager()
      share.VolunteerForm.remove(formId)
    else
      return throwError(403, 'Insufficient Permission')

  Meteor.methods "#{prefix}.volunteerForm.update": (doc) ->
    console.log ["#{prefix}.volunteerForm.update",doc]
    schema = share.VolunteerForm.simpleSchema()
    SimpleSchema.validate(doc.modifier,schema,{ modifier: true })
    oldDoc = share.VolunteerForm.findOne(doc._id)
    if (Meteor.userId() == oldDoc.userId) || share.isManager()
      share.VolunteerForm.update(doc._id,doc.modifier)
    else
      return throwError(403, 'Insufficient Permission')

  Meteor.methods "#{prefix}.volunteerForm.insert": (doc) ->
    console.log ["#{prefix}.volunteerForm.insert",doc]
    schema = share.VolunteerForm.simpleSchema()
    SimpleSchema.validate(doc,schema)
    if Meteor.userId()
      doc.userId = Meteor.userId()
      share.VolunteerForm.insert(doc)
    else
      return throwError(403, 'Insufficient Permission')

  Meteor.methods "#{prefix}.leadSignups.remove": (shiftId) ->
    console.log ["#{prefix}.leadSignups.remove",shiftId]
    check(shiftId,String)
    olddoc = share.LeadSignups.findOne(shiftId)
    if share.isManagerOrLead(Meteor.userId(),[olddoc.parentId])
      share.LeadSignups.remove(shiftId, (err,res) ->
        unless err
          if Meteor.isServer
            Roles.removeUsersFromRoles(olddoc.userId, olddoc.parentId, eventName)
        else
          return throwError(501, 'Cannot Remove')
        )
    else
      return throwError(403, 'Insufficient Permission')

  Meteor.methods "#{prefix}.leadSignups.confirm": (shiftId) ->
    console.log ["#{prefix}.leadSignups.confirm",shiftId]
    check(shiftId,String)
    olddoc = share.LeadSignups.findOne(shiftId)
    if share.isManagerOrLead(Meteor.userId(),[olddoc.parentId])
      modifier = { $set: {
        status: 'confirmed',
        reviewed: (olddoc.status == 'pending')
      }}
      share.LeadSignups.update(shiftId, modifier, (err,res) ->
        unless err
          if Meteor.isServer
            Roles.addUsersToRoles(olddoc.userId, olddoc.parentId, eventName)
        else
          return throwError(501, 'Cannot Update')
        )
    else
      return throwError(403, 'Insufficient Permission')

  Meteor.methods "#{prefix}.leadSignups.refuse": (shiftId) ->
    console.log ["#{prefix}.leadSignups.refuse",shiftId]
    check(shiftId,String)
    olddoc = share.LeadSignups.findOne(shiftId)
    if share.isManagerOrLead(Meteor.userId(),[olddoc.parentId])
      modifier = { $set: {
        status: 'refused',
        reviewed: (olddoc.status == 'pending')
      }}
      share.LeadSignups.update(shiftId, modifier, (err,res) ->
        unless err
          if Meteor.isServer
            Roles.removeUsersFromRoles(olddoc.userId, olddoc.parentId, eventName)
        else
          return throwError(501, 'Cannot Update')
        )
    else
      return throwError(403, 'Insufficient Permission')

  Meteor.methods "#{prefix}.leadSignups.insert": (doc) ->
    console.log ["#{prefix}.leadSignups.insert",doc]
    SimpleSchema.validate(doc,share.Schemas.LeadSignups.omit('status'))
    userId = Meteor.userId()
    lead = share.Lead.findOne(doc.shiftId)
    if (doc.userId == userId) || (share.isManagerOrLead(userId,[lead.parentId]))
      doc.status =
        switch lead.policy
          when "public" then "confirmed"
          when "requireApproval" then "pending"
      if doc.status
        signup = _.pick(doc,['userId','shiftId','parentId'])
        # avoid to book the same shift twice
        if Meteor.isServer
          { enrolled, status } = doc
          res = share.LeadSignups.upsert(signup, {
            $set: {status, enrolled,notification:false} }, (err,res) ->
              unless err
                if lead.policy == "public"
                  Roles.addUsersToRoles(doc.userId, lead.parentId, eventName)
              else
                return throwError(501, 'Cannot Insert')
          )
          # XXX we return an insertedId even if the function is called insert and should
          # return an simple id (or throw and error)
          if res?.insertedId?
            return res.insertedId
          else
          # XXX this part of the code is executed on the client and the LeadSignups
          # that we are inserting might not exist. In theory here we should make a
          # subscription and pull it from the server before trying to 'findOne'
            leadsu = share.LeadSignups.findOne(signup)
            return if leadsu? then leadsu._id
            
    else
      return throwError(403, 'Insufficient Permission')

  Meteor.methods "#{prefix}.leadSignups.bail": (sel) ->
    console.log ["#{prefix}.leadSignups.bail",sel]
    SimpleSchema.validate(sel,share.Schemas.LeadSignups.omit('status'))
    userId = Meteor.userId()
    olddoc = share.LeadSignups.findOne(sel)
    if (sel.userId == userId) || (share.isManagerOrLead(userId,[olddoc.parentId]))
      share.LeadSignups.update(sel,{$set: {status: "bailed"}},(err,res) ->
        unless err
          if Meteor.isServer
            Roles.removeUsersFromRoles(olddoc.userId, olddoc.parentId, eventName)
        else
          return throwError(501, 'Cannot Update')
        )
    else
      return throwError(403, 'Insufficient Permission')
