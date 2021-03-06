# Copyright (c) 2018 Public Library of Science

# Permission is hereby granted, free of charge, to any person obtaining a
# copy of this software and associated documentation files (the "Software"),
# to deal in the Software without restriction, including without limitation
# the rights to use, copy, modify, merge, publish, distribute, sublicense,
# and/or sell copies of the Software, and to permit persons to whom the
# Software is furnished to do so, subject to the following conditions:

# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
# THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
# FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
# DEALINGS IN THE SOFTWARE.

# Serves as the method for non-users to decline without having to sign in.
class TokenInvitationsController < ApplicationController
  before_action :ensure_user!, only: [:accept], unless: :current_user

  include ClientRouteHelper
  # rubocop:disable Style/AndOr, Metrics/LineLength
  def show
    render json: invitation, serializer: TokenInvitationSerializer
  end

  def update
    if invitation.invited? && invitation_update_params[:state] == 'declined'
      invitation.decline!
    elsif !invitation.feedback_given?
      invitation.update_attributes(invitation_update_params.except(:state))
    end
    render json: invitation, serializer: TokenInvitationSerializer
  end

  def accept
    redirect_to client_show_invitation_url(token: params[:token]) and return if invitation_inactive?
    if invitation.invited? and current_user.email == invitation.email
      invitation.actor = current_user
      invitation.accept!
      Activity.invitation_accepted!(invitation, user: current_user)
      flash[:notice] = thank_you_message
    end
    redirect_to "/papers/#{invitation.paper.to_param}"
  end

  private

  def invitation_update_params
    params.require(:token_invitation).permit(:state, :decline_reason, :reviewer_suggestions)
  end

  def invitation_inactive?
    invitation.declined? or invitation.rescinded?
  end

  def invitation
    @invitation ||= Invitation.find_by!(token: params[:token])
  end

  def thank_you_message
    journal_name = invitation.paper.journal.name
    base_message = if invitation.invitee_role == 'Reviewer'
                     "Thank you for agreeing to review for #{journal_name}."
                   else
                     "Thank you for agreeing to be an Academic Editor on this #{journal_name} manuscript."
                   end
    if params[:new_user]
      "Your PLOS account was successfully created. " + base_message
    else
      base_message
    end
  end

  def use_authentication?
    cas_phased_signup_disabled? or ned_unverified?
  end

  def cas_phased_signup_disabled?
    !TahiEnv.cas_phased_signup_enabled?
  end

  def ned_unverified?
    !NedUser.enabled? or NedUser.new.email_has_account?(invitation.email)
  end

  def ensure_user!
    if invitation.invitee.try(:ned_id) or use_authentication?
      if TahiEnv.cas_enabled?
        redirect_to omniauth_authorize_path(:user, 'cas', url: akita_invitation_accept_url)
      else
        authenticate_user!
      end
    else
      # ok, they are in an env with cas and they aren't in aperta yet
      # let redirect them to CAS with with with the JWT payload and a
      # redirect url. Based on the current CAS signup endpoint, they
      # use a destination param for redirect after signup. We'll keep
      # that for now until instructed otherwise. We want to know if a
      # user is returning from a phased signup so our destination param
      # will have a query param of its own for the action to pickup and
      # use for setting our sweet flash message.

      # url inception ahead, beware
      cas_uri = URI.parse(TahiEnv.cas_phased_signup_url)

      cas_uri.query = { token: jwt_encoded_payload }.to_query
      store_location_for(:user, akita_invitation_accept_url(new_user: true))
      redirect_to cas_uri.to_s
    end
  end

  def akita_invitation_accept_url(query_hash = {})
    arg_hash = {
      controller: 'token_invitations',
      action: 'accept',
      token: invitation.token
    }
    url_for(arg_hash.merge(query_hash))
  end

  def akita_omniauth_callback_url
    url_for(
      controller: 'tahi_devise/omniauth_callbacks',
      action: 'cas',
      url: akita_invitation_accept_url(new_user: true)
    )
  end

  def jwt_encoded_payload
    payload = {
      destination: akita_omniauth_callback_url,
      email: invitation.email,
      heading: thank_you_message,
      subheading:
        "Before you begin your review in Aperta,\
        please take a moment to create your PLOS account."
    }
    # get key from env? Abstract this into its own service?
    private_key = OpenSSL::PKey::EC.new(TahiEnv.jwt_id_ecdsa, nil)
    JWT.encode(payload, private_key, 'ES256')
  end
end
