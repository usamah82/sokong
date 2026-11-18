class QualificationsController < ApplicationController
  wrap_parameters false

  def create
    require_account
    return if performed?

    enrolment = linked_enrolment
    return render_not_found unless enrolment

    result = enrolment.mark(params[:outcome], worker: current_account)
    if result
      render json: { error: VerificationMessages.envelope(result) }, status: :unprocessable_content
      return
    end

    render json: {
      outcome: enrolment.outcome,
      marked_at: enrolment.marked_at.utc.iso8601,
      marker_name: enrolment.marker_name
    }, status: :created
  end

  private
    def linked_enrolment
      return unless current_account.role == "worker"

      Enrolment.where(locality_id: current_account.locality_assignments.select(:locality_id))
        .find_by(id: params[:id])
    end

    def render_not_found
      render json: { error: { code: "NOT_FOUND", message: "Not found" } }, status: :not_found
    end
end
