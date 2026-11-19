module VerificationMessages
  ENVELOPES = {
    visit_invalid: [ "Visit time is invalid", { visit_at: [ "is invalid" ] } ],
    visit_not_set: [ "Set the visit before recording it", {} ],
    basket_invalid: [ "Bringing a basket is invalid", { bringing_basket: [ "is invalid" ] } ],
    worker_required: [ "Assigned worker is required", { assigned_workers: [ "is required" ] } ],
    worker_invalid: [ "Assigned worker is invalid", { assigned_workers: [ "is invalid" ] } ],
    finished: [ "Verification is finished", {} ],
    outcome_required: [ "Outcome is required", { outcome: [ "is required" ] } ],
    outcome_invalid: [ "Outcome is invalid", { outcome: [ "is invalid" ] } ],
    finished_mark: [ "The mark is already set", { outcome: [ "is already set" ] } ],
    consent_refused: [ "The family has not consented", { outcome: [ "needs consent" ] } ],
    basket_required: [ "Basket is required", { basket: [ "is required" ] } ],
    basket_too_long: [ "Basket is too long", { basket: [ "is too long" ] } ],
    consent_required: [ "Consent is required", { consent_given: [ "is required" ] } ],
    identity_required: [ "Identity check is required", { identity: [ "is required" ] } ],
    identity_invalid: [ "Identity check is invalid", { identity: [ "is invalid" ] } ],
    relationship_required: [ "Relationship is required", { relationship: [ "is required" ] } ],
    relationship_invalid: [ "Relationship is invalid", { relationship: [ "is invalid" ] } ],
    good_family_unit_required: [ "Good family unit is required", { good_family_unit: [ "is required" ] } ],
    basic_necessities_required: [ "Basic necessities is required", { basic_necessities: [ "is required" ] } ],
    gap_required: [ "Gap is required", { gap: [ "is required" ] } ]
  }.freeze
  PARTS = %w[who_is_here formation daily_life dynamics house needs boxes].freeze

  def self.envelope(symbol)
    if PARTS.include?(symbol.to_s)
      return {
        code: "VALIDATION_ERROR",
        message: "The visit record is incomplete",
        details: { symbol.to_s => [ "is required" ] }
      }
    end

    message, details = ENVELOPES.fetch(symbol)
    { code: "VALIDATION_ERROR", message: message, details: details }
  end
end
