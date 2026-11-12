class EnrolmentsController < ApplicationController
  wrap_parameters false

  def index
    require_account
    return if performed?

    render json: visible_enrolments.map { |enrolment| enrolment_json(enrolment) }
  end

  def show
    require_account
    return if performed?

    enrolment = visible_enrolments.find_by(id: params[:id])
    if enrolment
      render json: enrolment_json(enrolment)
    else
      render json: { error: { code: "NOT_FOUND", message: "Not found" } }, status: :not_found
    end
  end

  def create
    submission = EnrolmentSubmission.new(params)
    if (error = submission.error_envelope)
      render json: { error: error }, status: :unprocessable_content
    else
      enrolment = submission.save
      queue_invitation(enrolment)
      render json: enrolment_json(enrolment), status: :created
    end
  end

  private
    def visible_enrolments
      return Enrolment.none unless current_account.role == "submitter"

      Enrolment.includes(:locality, :members)
        .where("lower(email) = ?", current_account.email_normalized)
        .order(submitted_at: :desc, created_at: :desc)
    end

    def queue_invitation(enrolment)
      return if enrolment.email.blank?

      EnrolmentMailer.invitation(enrolment.email).deliver_later
    rescue StandardError => error
      logger.info("Enrolment invitation was not queued: #{error.class}")
    end

    def enrolment_json(enrolment)
      {
        id: enrolment.id,
        submitted_at: enrolment.submitted_at.utc.iso8601,
        on_behalf: enrolment.on_behalf,
        consent_text: enrolment.consent_text,
        enroler_contact: enrolment.enroler_contact,
        email: enrolment.email,
        place_name: enrolment.place_name,
        # BigDecimal#as_json is a string in Rails 8.1. The contract is a JSON number.
        latitude: enrolment.latitude&.to_f,
        longitude: enrolment.longitude&.to_f,
        family_phone: enrolment.family_phone,
        how_to_find: enrolment.how_to_find,
        help: enrolment.help,
        other_help: enrolment.other_help,
        locality: { id: enrolment.locality.id, name: enrolment.locality.name },
        members: enrolment.members.map { |member| member_json(member) },
        progress: { case_in: true, looks: [], visit_at: nil }
      }
    end

    def member_json(member)
      {
        id: member.id,
        role: member.role,
        name: member.name,
        age: member.age,
        gender: member.gender,
        description: member.description,
        in_education: member.in_education,
        working: member.working,
        job: member.job,
        monthly_amount: member.monthly_amount
      }
    end
end
