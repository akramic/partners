import { buildURL } from "./ip_registry";
import { ajax } from "rxjs/ajax";

let subscription;

export const IPRegistryHook = {
  mounted() {
    const that = this;

    const handleNext = (data) => {
      // data is a json object so needs to be stringified to be stored in local storage
      window.localStorage.setItem("ip_registry_data", JSON.stringify(data));
      console.log("API call made");
      // Send the data back to the server
      that.pushEvent("ip_registry_data", {
        data: data,
      });
    };
    const handleError = (err) => {
      console.error("Error:", err);
    };
    const handleComplete = () => {
      console.log("Request completed");
    };

    const observer = {
      next: handleNext,
      error: handleError,
      complete: handleComplete,
    };

    this.pushEvent("get_api_key", {});

    this.handleEvent("get_api_key", (data) => {
      if (window.localStorage.getItem("ip_registry_data")) {
        console.log("NO API call made - retrieved from local storage");
        // The getItem call returns a string. This needs to parsed to a javascript object before sending to the server
        that.pushEvent("ip_registry_data", {
          data: JSON.parse(localStorage.getItem("ip_registry_data")),
        });
      } else {
        // We need to make an API call to get the data
        const { api_key } = data;
        // Provide the second arguement to the function to get the url to call
        const url = buildURL(api_key);
        subscription = ajax.getJSON(url).subscribe(observer);
      }
    });
  },

  destroyed() {
    // Cleanup if needed
    if (this.subscription) {
      this.subscription.unsubscribe();
    }
  },
};
