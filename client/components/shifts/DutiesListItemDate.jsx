import React, { Fragment } from 'react'

import { T } from '../common/i18n'
import { ProjectDate } from '../common/ProjectDate.jsx'
import { ShiftDate } from '../common/ShiftDate.jsx'
import { bailCall } from '../../utils/signups'
import { SignupButtons } from './SignupButtons.jsx'

export const DutiesListItemDate = ({
  start,
  end,
  type,
  signup,
  ...duty
}) => (
  <Fragment>
    {type === 'project'
      ? <ProjectDate start={start} end={end} />
      : <ShiftDate start={start} end={end} />}
    <div className="col p-0">
      {signup && signup.status !== 'bailed' ? (
        <div className="d-flex">
          <button
            className={`btn btn-action disabled
              ${signup.status === 'confirmed' ? 'btn-success' : ''}`}
            type="button"
          >
            <T>{signup.status}</T>
          </button>
          <button
            className="btn btn-primary btn-action"
            type="button"
            onClick={bailCall({ type, ...duty })}
          >
            <T>cancel</T>
          </button>
        </div>
      ) : <SignupButtons type={type} {...duty} />}
    </div>
  </Fragment>
)
