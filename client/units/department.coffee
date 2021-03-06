Template.departmentEdit.bindI18nNamespace('goingnowhere:volunteers')
Template.departmentEditDetails.bindI18nNamespace('goingnowhere:volunteers')
Template.departmentEditDetails.helpers
  'form': () -> { collection: share.Department }
  'data': () -> Template.currentData()

Template.departmentEdit.helpers
  'main': () ->
    id: "details"
    label: i18n.__("goingnowhere:volunteers","details")
    form: { collection: share.Department }
    data: Template.currentData()
  'tabs': () ->
    parentId = if Template.currentData() then Template.currentData()._id
    team =  {
      id: "team"
      label: i18n.__("goingnowhere:volunteers","team")
      tableFields: [ { name: 'name'} ]
      form: { collection: share.Team, filter: {parentId} }
      subscription : (template) ->
        [ share.templateSub(template,"team.backend",parentId) ]
      }
    lead =  {
      id: "leads"
      label: i18n.__("goingnowhere:volunteers","leads")
      tableFields: [
       { name: 'title' },
       { name: 'userId', template:"teamLeadField"},
      ]
      form: { collection: share.Lead, filter: {parentId} }
      subscription : (template) ->
        [ share.templateSub(template,"LeadSignups.byDepartment",parentId) ]
      }
    return [team,lead]

AutoForm.addHooks ['InsertDepartmentFormId'],
  onSuccess: (formType, result) ->
    console.log this.template
    # this.template.currentLead.set({teamId:result._id})
