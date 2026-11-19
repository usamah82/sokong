class EnrolmentsController < ApplicationController
  wrap_parameters false

  def index
    require_account
    return if performed?

    if current_account.role == "worker" && !current_account.locality_assignments.exists?
      render json: {
        error: {
          code: "FORBIDDEN",
          message: "No locality is linked to this account."
        }
      }, status: :forbidden
      return
    end

    render json: visible_enrolments.map { |enrolment|
      current_account.role == "worker" ? worker_summary_json(enrolment) : enrolment_json(enrolment)
    }
  end

  def show
    require_account
    return if performed?

    enrolment = visible_enrolments.find_by(id: params[:id])
    return render_not_found unless enrolment

    if current_account.role == "worker"
      record_first_look(enrolment)
      render json: worker_detail_json(enrolment)
    else
      render json: enrolment_json(enrolment)
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
      relation = Enrolment.includes(:locality, :members, :looks, :verification).order(submitted_at: :desc, created_at: :desc)
      case current_account.role
      when "submitter"
        relation.where("lower(email) = ?", current_account.email_normalized)
      when "worker"
        relation.where(locality_id: current_account.locality_assignments.select(:locality_id))
      else
        Enrolment.none
      end
    end

    def record_first_look(enrolment)
      enrolment.with_lock do
        return if enrolment.looks.exists?(account_id: current_account.id)

        enrolment.looks.create!(
          account: current_account,
          worker_name: current_account.name,
          looked_at: Time.current,
          note: ""
        )
      end
    end

    def render_not_found
      render json: { error: { code: "NOT_FOUND", message: "Not found" } }, status: :not_found
    end

    def worker_summary_json(enrolment)
      {
        id: enrolment.id,
        submitted_at: enrolment.submitted_at.utc.iso8601,
        place_name: enrolment.place_name,
        head_name: enrolment.members.find { |member| member.role == "head" }&.name,
        enroler_contact: enrolment.enroler_contact,
        on_behalf: enrolment.on_behalf,
        locality: { id: enrolment.locality.id, name: enrolment.locality.name },
        visit_at: enrolment.visit_at&.utc&.iso8601,
        outcome: enrolment.outcome
      }
    end

    def worker_detail_json(enrolment)
      worker_summary_json(enrolment).merge(
        email: enrolment.email,
        how_to_find: enrolment.how_to_find,
        family_phone: enrolment.family_phone,
        help: enrolment.help,
        other_help: enrolment.other_help,
        consent_text: enrolment.consent_text,
        latitude: enrolment.latitude&.to_f,
        longitude: enrolment.longitude&.to_f,
        members: enrolment.members.map { |member| member_json(member) },
        looks: enrolment.looks.map { |look| look_json(look) },
        bringing_basket: enrolment.bringing_basket,
        assigned_workers: enrolment.assigned_workers,
        verification: verification_json(enrolment),
        marked_at: enrolment.marked_at&.utc&.iso8601,
        marker_name: enrolment.marker_name
      )
    end

    def verification_json(enrolment)
      record = enrolment.verification
      return unless record

      {
        who_is_here: record.who_is_here,
        formation: record.formation,
        daily_life: record.daily_life,
        dynamics: record.dynamics,
        house: record.house,
        needs: record.needs,
        boxes: record.boxes
      }
    end

    def look_json(look)
      {
        id: look.id,
        worker_name: look.worker_name,
        looked_at: look.looked_at.utc.iso8601,
        note: look.note
      }
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
        progress: {
          case_in: true,
          looks: enrolment.looks.map { |look| look_json(look) },
          visit_at: enrolment.visit_at&.utc&.iso8601,
          outcome: enrolment.outcome
        }
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
