defmodule PartnersWeb.Subscription.Components.SubscriptionComponents do
  @moduledoc """
  This module contains components for the subscription process.
  """

  use Phoenix.Component
  use PartnersWeb, :html

  @doc """
  Renders the subscription component based on the live_action.
  """
  def render(%{live_action: :start_trial} = assigns) do
    ~H"""
    <div class="space-y-8 flex flex-col items-center">
      <p>Your free trial is just one click away!</p>
      <p>Confirm your trial with Paypal</p>
      <button
        phx-click="request_paypal_approval_url"
        class="gap-4 mt-2 inline-flex items-center justify-center px-6 py-3 border border-transparent rounded-full shadow-sm text-base font-medium text-[#003087] bg-[#ffc439] hover:bg-[#f5bb00] focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-[#f5bb00]"
      >
        <span>Subscribe</span>
        <img src="/images/paypal_logo.svg" alt="PayPal" class="mr-2 h-5 w-auto" />
      </button>
      <div
        :if={@transferring_to_paypal}
        class="z-50 absolute inset-0 flex items-center justify-center bg-base-200"
      >
        <div class="flex flex-col items-center justify-center space-y-4 py-4 px-8 rounded-md bg-base-100/70 shadow-lg">
          <span class="inline-block loading loading-ring loading-sm"></span>
          <p class="text-sm">Transferring to</p>
          <img src="/images/paypal_logo.svg" alt="PayPal" class="mr-2 h-5 w-auto" />
        </div>
      </div>
    </div>
    """
  end

  def render(%{live_action: :paypal_return} = assigns) do
    ~H"""
    <div class="space-y-8 flex flex-col items-center">
      <p>Thank you for your subscription!</p>
      <p>We are setting up your account.</p>
      <p>Redirecting...</p>
    </div>
    """
  end

  def render(%{live_action: :paypal_cancel} = assigns) do
    ~H"""
    <div class="space-y-8 flex flex-col items-center">
      <p>Looks like you decided not to go ahead</p>
      <p>Don't forget, your trial is free for 7 days. Pay nothing today. Want to try again?</p>
      <button
        phx-click="request_paypal_approval_url"
        class="gap-4 mt-2 inline-flex items-center justify-center px-6 py-3 border border-transparent rounded-full shadow-sm text-base font-medium text-[#003087] bg-[#ffc439] hover:bg-[#f5bb00] focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-[#f5bb00]"
      >
        <span>Subscribe</span>
        <img src="/images/paypal_logo.svg" alt="PayPal" class="mr-2 h-5 w-auto" />
      </button>
      <div
        :if={@transferring_to_paypal}
        class="z-50 absolute inset-0 flex items-center justify-center bg-base-200"
      >
        <div class="flex flex-col items-center justify-center space-y-4 py-4 px-8 rounded-md bg-base-100/70 shadow-lg">
          <span class="inline-block loading loading-ring loading-sm"></span>
          <p class="text-sm">Transferring to</p>
          <img src="/images/paypal_logo.svg" alt="PayPal" class="mr-2 h-5 w-auto" />
        </div>
      </div>
    </div>
    """
  end

  # Fallback for any unhandled live_action
  def render(assigns) do
  ~H"""
  <div class="space-y-8 flex flex-col items-center">
    <h1 class="text-4xl font-bold text-red-500">404</h1>
    <p class="text-xl">Page not found</p>
    <p>The page you're looking for doesn't exist or has been moved.</p>
    <.link navigate={~p"/subscriptions/start_trial"} class="btn btn-primary mt-4">Start trial subscription</.link>
  </div>
  """
end
end
