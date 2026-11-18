class VisitsController < ApplicationController
  wrap_parameters false

  def update
    require_account
    return if performed?

    enrolment = linked_enrolment
    return render_not_found unless enrolment

    result = enrolment.schedule_visit(
      visit_at: params[:visit_at],
      bringing_basket: params[:bringing_basket],
      assigned_workers: params[:assigned_workers]
    )
    if result.is_a?(Symbol)
      render json: { error: VerificationMessages.envelope(result) }, status: :unprocessable_content
      return
    end

    render json: enrolment.pre_visit_json
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
