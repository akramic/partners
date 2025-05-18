defmodule PartnersWeb.Subscription.Components.SubscriptionComponents do
  @moduledoc """
  This module contains components for the PayPal subscription process.

  The components handle different states of the PayPal subscription flow:

  1. `:start_trial` - Initial subscription page with PayPal button
  2. `:paypal_return` - Shows when a user returns after approving a subscription on PayPal
     This component displays a modal with a loading spinner while the system processes
     the PayPal approval in the background. The modal provides visual feedback that
     the subscription is being set up and prevents user interaction until complete.
  3. `:paypal_cancel` - Displayed when a user cancels the PayPal subscription process
  4. `:subscription_activated` - Success view shown after receiving PayPal's activation webhook
     This confirms to the user that their trial subscription is now active.

  Each component includes appropriate loading states and transitions between different
  stages of the subscription process. The components are selected based on the current
  `live_action` value, which changes as the user progresses through the subscription flow.
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
    <div class="z-50 absolute inset-0 flex items-center justify-center bg-base-200">
      <div class="space-y-8 flex flex-col items-center">
        <div class="flex flex-col items-center justify-center space-y-2 py-4 px-8 rounded-md bg-base-100 shadow-lg">
          <p>You're awesome! <span>&#128151;</span></p>
          <p>Thank you for your subscription!</p>
          <p>Waiting for Paypal approval.</p>
          <span class="inline-block loading loading-ring loading-lg"></span>
          <p class="text-sm">Should be just a moment or two ...</p>
        </div>
      </div>
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

  def render(%{live_action: :subscription_activated} = assigns) do
    ~H"""
    <div class="space-y-8 flex flex-col items-center">
      <p>Well done!</p>
      <p>Your subscription is now active.</p>
      <p>Thank you for choosing our service!</p>
    </div>
    """
  end

  # def render(%{live_action: :subscription_rejected} = assigns) do
  #   ~H"""
  #   <div class=" flex flex-col items-center">
  #     <p class="text-xl font-semibold"><span>&#128542;</span> Subscription Issue</p>

  #     <div class="p-4 bg-base-200 rounded-lg max-w-lg space-y-8 ">
  #       <%= case @subscription_status do %>
  #         <% :payment_failed -> %>
  #           <p>PayPal was unable to set up your free trial subscription.</p>
  #           <p class="mt-2">
  #             This appears to be related to their verification process. Please note that we have not attempted to take any payments from your PayPal account.
  #           </p>
  #         <% :payment_denied -> %>
  #           <p>PayPal was unable to authorize your free trial subscription.</p>
  #           <p class="mt-2">
  #             This is typically related to security measures on their platform. Please note that we have not attempted to take any payments from your PayPal account.
  #           </p>
  #         <% :dispute_created -> %>
  #           <p>PayPal has placed your subscription under review.</p>
  #           <p class="mt-2">
  #             This is a security measure that PayPal sometimes takes to prevent fraud.
  #           </p>
  #           <p class="mt-2">
  #             PayPal will review this transaction manually, which may take 24-72 hours. You do not need to take any action during this time.
  #           </p>
  #           <p class="mt-2">
  #             If approved, your subscription will activate automatically. If denied, PayPal will send you a notification with details.
  #           </p>
  #           <p class="mt-2">
  #             Please note that we have not attempted to take any payments from your PayPal account.
  #           </p>
  #         <% _ -> %>
  #           <p>
  #             There was an issue setting up your subscription. We have not been given any other information.
  #           </p>
  #       <% end %>

  #       <p class="mt-4">Since this is a Paypal subscription processing issue, please:</p>
  #       <ul class="list-disc text-left pl-8 mt-2">
  #         <li>Check your PayPal account for any alerts or restrictions</li>
  #         <li>Verify your payment method details in your PayPal account</li>
  #         <li>Contact PayPal support for specific details about this rejection</li>
  #       </ul>

  #       <div class="mt-4 p-3 bg-base-100 rounded border border-base-300 text-center space-y-4">
  #         <p class="font-medium">Contact PayPal support</p>
  #         <p :if={@subscription_id} class="text-sm mt-1">
  #           Paypal subscription ID: <span class="font-mono">{@subscription_id}</span>
  #         </p>
  #         <p class="text-sm mt-1 flex justify-center">
  #           <a
  #             href="https://www.paypal.com/smarthelp/contact-us"
  #             target="_blank"
  #             rel="noopener noreferrer"
  #             class="text-blue-500 hover:underline flex items-center"
  #           >
  #             PayPal Support
  #             <svg
  #               xmlns="http://www.w3.org/2000/svg"
  #               fill="none"
  #               viewBox="0 0 24 24"
  #               stroke-width="1.5"
  #               stroke="currentColor"
  #               class="ml-1 w-4 h-4"
  #             >
  #               <path
  #                 stroke-linecap="round"
  #                 stroke-linejoin="round"
  #                 d="M13.5 6H5.25A2.25 2.25 0 003 8.25v10.5A2.25 2.25 0 005.25 21h10.5A2.25 2.25 0 0018 18.75V10.5m-10.5 6L21 3m0 0h-5.25M21 3v5.25"
  #               />
  #             </svg>
  #           </a>
  #         </p>
  #       </div>
  #     </div>

  #     <div class="mt-4 flex flex-col space-y-4">
  #       <p>The good news is your loving.partners account has been created successfully.</p>
  #       <p class="mt-2">
  #         Once you've resolved this with PayPal, you can log in anytime to complete your free trial subscription. We're looking forward to seeing you again!
  #       </p>
  #       <.link navigate={~p"/"} class="btn btn-primary mt-4">
  #         Home
  #       </.link>
  #     </div>
  #   </div>
  #   """
  # end

  # Fallback for any unhandled live_action
  def render(assigns) do
    ~H"""
    <div class="space-y-8 flex flex-col items-center">
      <h1 class="text-4xl font-bold text-red-500">404</h1>
      <p class="text-xl">Page not found</p>
      <p>The page you're looking for doesn't exist or has been moved.</p>
      <.link navigate={~p"/subscriptions/start_trial"} class="btn btn-primary mt-4">
        Start trial subscription
      </.link>
    </div>
    """
  end
end
