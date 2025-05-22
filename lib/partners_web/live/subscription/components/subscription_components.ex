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
  5. `:subscription_rejected` - Shown when there's an issue with PayPal subscription setup
     * Handles both initial rejection and retry scenarios
     * Offers troubleshooting steps based on retry status
     * Provides PayPal support contact information after failed retries

  Each component includes appropriate loading states and transitions between different
  stages of the subscription process. The components are selected based on the current
  `live_action` value, which changes as the user progresses through the subscription flow.

  The components also track retry attempts for subscription failures, showing progressively
  more detailed troubleshooting guidance when retries fail.
  """

  use Phoenix.Component
  use PartnersWeb, :html
  alias PartnersWeb.CustomComponents.Typography

  @doc """
  Renders the subscription component based on the live_action.
  """
  def render(%{live_action: :start_trial} = assigns) do
    ~H"""
    <div class="space-y-8 flex flex-col items-center">
      <Typography.p>Your free trial is just one click away!</Typography.p>
      <Typography.p>Confirm your trial with Paypal</Typography.p>
      <div class="flex flex-col items-center justify-center space-y-2 mb-20 my-[calc(clamp(1.75rem,2vw,6rem)*1.2)]">
        <button
          phx-click="request_paypal_approval_url"
          class="gap-4 mt-2 inline-flex items-center justify-center px-6 py-3 border border-transparent rounded-full shadow-sm text-base font-medium text-[#003087] bg-[#ffc439] hover:bg-[#f5bb00] focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-[#f5bb00]"
        >
          <Typography.p class="uppercase">Subscribe</Typography.p>
          <img src="/images/paypal_logo.svg" alt="PayPal" class="mr-2 h-5 w-auto" />
        </button>
      </div>
      <div
        :if={@transferring_to_paypal}
        class="z-50 absolute inset-0 flex items-center justify-center bg-base-200"
      >
        <div class="flex flex-col items-center justify-center space-y-4 py-4 px-8 rounded-md bg-base-100/70 shadow-lg">
          <span class="inline-block loading loading-ring loading-sm"></span>
          <Typography.p class="text-sm">Transferring to</Typography.p>
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
          <Typography.p>
            You're awesome! <span aria-label="heart" role="img">&#128151;</span>
          </Typography.p>
          <Typography.p>Thank you for your subscription!</Typography.p>
          <Typography.p>We're waiting for your approval from Paypal.</Typography.p>
          <span class="inline-block loading loading-ring loading-lg"></span>
          <Typography.p class="text-sm">
            This can take up to two minutes. Don't go anywhere ...
          </Typography.p>
        </div>
      </div>
    </div>
    """
  end

  def render(%{live_action: :paypal_cancel} = assigns) do
    ~H"""
    <div class="space-y-8 flex flex-col items-center">
      <Typography.p>Looks like you decided not to go ahead</Typography.p>
      <Typography.p>
        Don't forget, your trial is free for 7 days. Pay nothing today. Want to try again?
      </Typography.p>
      <button
        phx-click="request_paypal_approval_url"
        class="gap-4 mt-2 inline-flex items-center justify-center px-6 py-3 border border-transparent rounded-full shadow-sm text-base font-medium text-[#003087] bg-[#ffc439] hover:bg-[#f5bb00] focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-[#f5bb00]"
      >
        <Typography.p class="uppercase">Subscribe</Typography.p>
        <img src="/images/paypal_logo.svg" alt="PayPal" class="mr-2 h-5 w-auto" />
      </button>
      <div
        :if={@transferring_to_paypal}
        class="z-50 absolute inset-0 flex items-center justify-center bg-base-200"
      >
        <div class="flex flex-col items-center justify-center space-y-4 py-4 px-8 rounded-md bg-base-100/70 shadow-lg">
          <span class="inline-block loading loading-ring loading-sm"></span>
          <Typography.p class="text-sm">Transferring to</Typography.p>
          <img src="/images/paypal_logo.svg" alt="PayPal" class="mr-2 h-5 w-auto" />
        </div>
      </div>
    </div>
    """
  end

  def render(%{live_action: :subscription_activated} = assigns) do
    ~H"""
    <div class="space-y-8 flex flex-col items-center">
      <Typography.p>Well done!</Typography.p>
      <Typography.p>Your subscription is now active.</Typography.p>
      <Typography.p>Thank you for choosing our service!</Typography.p>
    </div>
    """
  end

  def render(%{live_action: :subscription_rejected} = assigns) do
    ~H"""
    <div>
      <div :if={!@retry} class=" flex flex-col items-center">
        <%!-- Clamp used for responsive margins --%>
        <div class="my-[calc(clamp(1.75rem,2vw,6rem)*1.2)]">
          <Typography.h4 class="font-semibold ">
            Subscription Issue <span aria-label="sad face" role="img">&#128542;</span>
          </Typography.h4>
        </div>
        <div class="p-4 bg-base-200 rounded-lg space-y-8 ">
          <Typography.p>
            Looks like there was a problem with Paypal setting up your trial subscription.
          </Typography.p>
          <Typography.p>
            We waited for confirmation from Paypal that your trial subscription was set up but nothing was received.
          </Typography.p>
          <Typography.p>
            This issue can happen for a number of reasons and is usually temporary if your Paypal account is in good order. Trying again in a few minutes usually works. You can retry by clicking the button below.
          </Typography.p>
          <%!-- Clamp used for responsive margins --%>
          <div class="flex flex-col items-center justify-center space-y-2 mb-20 my-[calc(clamp(2rem,2vw,6rem)*1.2)]">
            <button
              phx-click="request_paypal_approval_url"
              phx-value-retry="true"
              class="gap-4 mt-2 inline-flex items-center justify-center px-6 py-3 border border-transparent rounded-full shadow-sm text-base font-medium text-[#003087] bg-[#ffc439] hover:bg-[#f5bb00] focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-[#f5bb00]"
            >
              <Typography.p class="uppercase">Subscribe</Typography.p>
              <img src="/images/paypal_logo.svg" alt="PayPal" class="mr-2 h-5 w-auto" />
            </button>
          </div>
        </div>
      </div>

      <div :if={@retry} class=" flex flex-col items-center space-y-10">
        <div class="my-[calc(clamp(1.75rem,2vw,6rem)*1.2)]">
          <Typography.h4 class="font-semibold ">
            Retry failed <span aria-label="sad face" role="img">&#128542;</span>
          </Typography.h4>
        </div>

        <Typography.p class="mt-4">
          Sorry, we still didn't receive confirmation from Paypal that your subscription was correctly set up. Looks like there's an issue with Paypal.
        </Typography.p>
        <div class="flex justify-center">
          <ul class=" items-center list-disc text-left pl-8 mt-2 text-[clamp(1rem,2vw,1.5rem)] leading-[calc(clamp(1rem,2vw,1.5rem)*1.6)]">
            <li>Check your PayPal account for any alerts or restrictions</li>
            <li>Verify you have a valid payment method set up in your PayPal account</li>
            <li>Contact PayPal support for further help with this issue</li>
          </ul>
        </div>

        <div class="mt-4 p-3 bg-base-100 rounded border border-base-300 text-center space-y-4">
          <Typography.p class="font-medium">Contact PayPal support</Typography.p>

          <Typography.p :if={@subscription_id} class=" mt-1">
            Paypal subscription ID: <span class="font-mono">{@subscription_id}</span>
          </Typography.p>
          <Typography.p :if={!@subscription_id} class=" mt-1">
            We did not receive a reference subscription ID from Paypal.
          </Typography.p>
          <Typography.p class="text-sm mt-1 flex justify-center">
            <a
              href="https://www.paypal.com/smarthelp/contact-us"
              target="_blank"
              rel="noopener noreferrer"
              class="text-blue-500 hover:underline flex items-center"
            >
              PayPal Support
              <svg
                xmlns="http://www.w3.org/2000/svg"
                fill="none"
                viewBox="0 0 24 24"
                stroke-width="1.5"
                stroke="currentColor"
                class="ml-1 w-4 h-4"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  d="M13.5 6H5.25A2.25 2.25 0 003 8.25v10.5A2.25 2.25 0 005.25 21h10.5A2.25 2.25 0 0018 18.75V10.5m-10.5 6L21 3m0 0h-5.25M21 3v5.25"
                />
              </svg>
            </a>
          </Typography.p>
        </div>
        <div class="mt-4 flex flex-col space-y-4">
          <Typography.p class="mt-2">
            Once you've resolved this with PayPal, you can log in anytime to complete your free trial subscription.
          </Typography.p>
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
      <Typography.p class="text-xl">Page not found</Typography.p>
      <Typography.p>The page you're looking for doesn't exist or has been moved.</Typography.p>
      <.link navigate={~p"/subscriptions/start_trial"} class="btn btn-primary mt-4">
        Start trial subscription
      </.link>
    </div>
    """
  end
end
