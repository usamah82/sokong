class VisitsController < ApplicationController
  wrap_parameters false

  def update
    require_account
    return if performed?

    enrolment = linked_enrolment
    return render_not_found unless enrolment

    previous_visit_at = enrolment.visit_at
    result = enrolment.schedule_visit(
      visit_at: params[:visit_at],
      bringing_basket: params[:bringing_basket],
      assigned_workers: params[:assigned_workers]
    )
    if result.is_a?(Symbol)
      render json: { error: VerificationMessages.envelope(result) }, status: :unprocessable_content
      return
    end

    queue_visit_message(enrolment, previous_visit_at:)
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

    def queue_visit_message(enrolment, previous_visit_at:)
      return if enrolment.email.blank?
      return if previous_visit_at&.change(usec: 0) == enrolment.visit_at&.change(usec: 0)

      head = enrolment.members.find { |member| member.role == "head" }&.name
      label = EnrolmentMailer.utc_label(enrolment.visit_at)
      message = if previous_visit_at.nil?
        EnrolmentMailer.visit_set(enrolment.email, head, enrolment.place_name, label)
      else
        EnrolmentMailer.visit_changed(enrolment.email, head, enrolment.place_name, label)
      end
      message.deliver_later
    rescue StandardError => error
      logger.info("Visit message was not queued: #{error.class}")
    end
end
