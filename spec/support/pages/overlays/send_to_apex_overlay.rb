require 'support/pages/card_overlay'

# SendToApexOverlay is a test helper for the "Send to Apex" overlay used by
# the application.
class SendToApexOverlay < CardOverlay
  def ensure_apex_upload_is_pending
    expect(page).to have_selector('.overlay .export-delivery', text: 'pending')
  end

  def ensure_apex_upload_has_succeeded
    expect(page).to have_selector('.overlay .export-delivery', text: 'succeeded')
  end
end
