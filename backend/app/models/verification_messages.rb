module VerificationMessages
  ENVELOPES = {
    visit_invalid: [ "Visit time is invalid", { visit_at: [ "is invalid" ] } ],
    visit_not_set: [ "Set the visit before recording it", {} ],
    basket_invalid: [ "Bringing a basket is invalid", { bringing_basket: [ "is invalid" ] } ],
    worker_required: [ "Assigned worker is required", { assigned_workers: [ "is required" ] } ],
    worker_invalid: [ "Assigned worker is invalid", { assigned_workers: [ "is invalid" ] } ]
  }.freeze

  def self.envelope(symbol)
    message, details = ENVELOPES.fetch(symbol)
    { code: "VALIDATION_ERROR", message: message, details: details }
  end
end
