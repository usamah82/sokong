class EnrolmentsController < ApplicationController
  def create
    submission = EnrolmentSubmission.new(request.request_parameters)

    if submission.valid?
      render json: submission.save!.response_body, status: :created
    else
      render json: submission.error_envelope, status: :unprocessable_entity
    end
  end
end
