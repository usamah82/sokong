class LooksController < ApplicationController
  wrap_parameters false

  def create
    require_account
    return if performed?

    enrolment = linked_enrolment
    return render_not_found unless enrolment

    if (error = note_error(params[:note]))
      render json: { error: error }, status: :unprocessable_content
      return
    end

    look = enrolment.looks.create!(
      account: current_account,
      worker_name: current_account.name,
      looked_at: Time.current,
      note: params[:note].strip
    )
    render json: {
      id: look.id,
      worker_name: look.worker_name,
      looked_at: look.looked_at.utc.iso8601,
      note: look.note
    }, status: :created
  end

  private
    def linked_enrolment
      return unless current_account.role == "worker"

      Enrolment.where(locality_id: current_account.locality_assignments.select(:locality_id))
        .find_by(id: params[:enrolment_id])
    end

    def note_error(note)
      unless note.is_a?(String)
        return { code: "VALIDATION_ERROR", message: "Note is invalid", details: { note: [ "is invalid" ] } }
      end

      cleaned = note.strip
      if cleaned.empty?
        { code: "VALIDATION_ERROR", message: "Note is required", details: { note: [ "is required" ] } }
      elsif cleaned.length > 2000
        { code: "VALIDATION_ERROR", message: "Note is too long", details: { note: [ "is too long" ] } }
      end
    end

    def render_not_found
      render json: { error: { code: "NOT_FOUND", message: "Not found" } }, status: :not_found
    end
end
