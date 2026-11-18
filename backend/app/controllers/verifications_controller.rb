class VerificationsController < ApplicationController
  wrap_parameters false

  def update
    require_account
    return if performed?

    enrolment = linked_enrolment
    return render_not_found unless enrolment
    return render_not_found unless params[:stage] == "who_is_here"

    if enrolment.visit_at.nil?
      render json: { error: VerificationMessages.envelope(:visit_not_set) }, status: :unprocessable_content
      return
    end

    result = WhoIsHereStage.clean(stage_input, enrolment:)
    if result[:error]
      render json: { error: result[:error] }, status: :unprocessable_content
      return
    end

    verification = enrolment.verification || enrolment.build_verification
    recorded_at = Time.current.utc.change(usec: 0).iso8601
    verification.update!(who_is_here: result.merge("worker_name" => current_account.name, "recorded_at" => recorded_at))
    render json: verification.who_is_here
  end

  private
    def stage_input
      params.to_unsafe_h.slice(
        "people", "others_stay", "others_stay_detail",
        "care_for_parents", "care_for_parents_detail", "notes"
      )
    end

    def linked_enrolment
      return unless current_account.role == "worker"

      Enrolment.where(locality_id: current_account.locality_assignments.select(:locality_id))
        .find_by(id: params[:id])
    end

    def render_not_found
      render json: { error: { code: "NOT_FOUND", message: "Not found" } }, status: :not_found
    end
end
