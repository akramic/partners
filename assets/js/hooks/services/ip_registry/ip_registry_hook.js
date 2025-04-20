import { buildURL } from "./ip_registry";
import { ajax } from "rxjs/ajax";

/*

This hook is used to get the IP registry data from either an API call to IPRegistry and store it in localStorage or from localStorage if the data is already stored.

Note that if an API call is required - we also need to handle getting the headers which contains the api credits remaining.
So the the whole of the response body is sent back to the server - we check the headers and send an email if credits fall below a threshold value.

If data is retrieved from localStorage we only send back the response without the headers.


*/

let subscription;

export const IPRegistryHook = {
  mounted() {
    const that = this;

    // Functions for the observer object
    const handleNext = (data) => {
      // data contains the response which is a json object so needs to be stringified to be stored in local storage
      window.localStorage.setItem(
        "ip_registry_data",
        JSON.stringify(data.response)
      );
      console.log("API call made");
      // We send the whole of the data including the headers back to the server which will tell us the credits remaining for API calls
      that.pushEvent("ip_registry_data", { status: "OK", result: data });
    };
    const handleError = (err) => {
      that.pushEvent("ip_registry_data", { status: "ERROR", result: err });
      console.error("Error:", err);
    };
    const handleComplete = () => {
      console.log("Request completed");
    };

    // The observer object is used to handle the response from the API call
    const observer = {
      next: handleNext,
      error: handleError,
      complete: handleComplete,
    };
    // Starts of the process by sending a message to the server to get the api key
    this.pushEvent("get_api_key", {});

    this.handleEvent("get_api_key", (data) => {
      if (window.localStorage.getItem("ip_registry_data")) {
        console.log("NO API call made - retrieved from local storage");
        // The getItem call returns a string. This needs to parsed to a javascript object before sending to the server
        that.pushEvent("ip_registry_data", {
          status: "OK",
          result: JSON.parse(localStorage.getItem("ip_registry_data")),
        });
      } else {
        //   We need to make an API call to get the data
        const { api_key } = data;
        // Provide the second arguement to the partially applied function to get the url to call
        const url = buildURL(api_key);
        subscription = ajax(url).subscribe(observer);
      }
    });
  },

  destroyed() {
    // Cleanup if needed. The API call should automatically cleanup the subscription
    if (this.subscription) {
      this.subscription.unsubscribe();
    }
  },
};
