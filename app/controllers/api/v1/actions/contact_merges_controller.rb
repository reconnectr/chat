class Api::V1::Actions::ContactMergesController < Api::BaseController
  before_action :set_base_contact, only: [:create]
  before_action :set_mergee_contact, only: [:create]

  def create
    contact_merge_action = ContactMergeAction.new(
      account: current_account,
      base_contact: @base_contact,
      mergee_contact: @mergee_contact
    )
    contact_merge_action.perform
    render json: @base_contact
  end

  private

  def set_base_contact
    @base_contact = contacts.find(params[:base_contact_id])
  end

  def set_mergee_contact
    @mergee_contact = contacts.find(params[:mergee_contact_id])
  end

  def contacts
    @contacts ||= current_account.contacts
  end
end
