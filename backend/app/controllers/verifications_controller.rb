class VerificationsController < ApplicationController
  wrap_parameters false

  CLEANERS = {
    "who_is_here" => WhoIsHereStage,
    "formation" => FormationStage,
    "dynamics" => DynamicsStage
  }.freeze

  def update
    require_account
    return if performed?

    enrolment = linked_enrolment
    return render_not_found unless enrolment

    cleaner = CLEANERS[params[:stage]]
    return render_not_found unless cleaner

    if enrolment.visit_at.nil?
      render json: { error: VerificationMessages.envelope(:visit_not_set) }, status: :unprocessable_content
      return
    end

    result = cleaner.clean(params.to_unsafe_h.slice(*cleaner::KEYS), enrolment:)
    if result[:error]
      render json: { error: result[:error] }, status: :unprocessable_content
      return
    end

    verification = enrolment.verification || enrolment.build_verification
    recorded_at = Time.current.utc.change(usec: 0).iso8601
    stored = result.merge("worker_name" => current_account.name, "recorded_at" => recorded_at)
    case params[:stage]
    when "who_is_here"
      verification.update!(who_is_here: stored)
      render json: verification.who_is_here
    when "formation"
      verification.update!(formation: stored)
      render json: verification.formation
    when "dynamics"
      verification.update!(dynamics: stored)
      render json: verification.dynamics
    end
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
