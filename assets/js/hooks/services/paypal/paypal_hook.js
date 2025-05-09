// PayPal Hook for handling PayPal-related browser interactions
export const PaypalHook = {
  mounted() {
    // Add event listener for the open-paypal event
    this.handleEvent("open-paypal", ({ url }) => {
      if (url) {
        // Open PayPal approval URL in a new tab/window
        window.open(url, "_blank");

        // Show a message to the user that they need to complete the process in the new window
        console.log("PayPal approval window opened. Please complete the subscription in the new window.");
      }
    });
  }
};
