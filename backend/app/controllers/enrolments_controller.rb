class EnrolmentsController < ApplicationController
  wrap_parameters false

  def create
    submission = EnrolmentSubmission.new(params)
    if (error = submission.error_envelope)
      render json: { error: error }, status: :unprocessable_content
    else
      render json: enrolment_json(submission.save), status: :created
    end
  end

  private
    def enrolment_json(enrolment)
      {
        id: enrolment.id,
        submitted_at: enrolment.submitted_at.utc.iso8601,
        on_behalf: enrolment.on_behalf,
        consent_text: enrolment.consent_text,
        enroler_contact: enrolment.enroler_contact,
        email: enrolment.email,
        place_name: enrolment.place_name,
        latitude: enrolment.latitude,
        longitude: enrolment.longitude,
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
