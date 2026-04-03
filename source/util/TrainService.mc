import Toybox.Lang;

using Toybox.Communications;

(:glance)
class TrainService {

    private var trains_        as Array<Train>;
    private var pending_       as Boolean;
    private var isRetry_      as Boolean;
    private var busService_    as Boolean;
    private var error_         as String or Null;
    private var pendingFrom_   as String;
    private var onDataChanged_ as Lang.Method;
    private var requester_     as WebRequester;

    function initialize(onDataChanged as Lang.Method, requester as WebRequester) {
        trains_        = new Array<Train>[0];
        pending_       = false;
        isRetry_      = false;
        busService_    = false;
        error_         = null;
        pendingFrom_   = "";
        onDataChanged_ = onDataChanged;
        requester_     = requester;
    }

    function getTrains() as Array<Train> {
        return trains_;
    }

    function isPending() as Boolean {
        return pending_;
    }

    function isBusService() as Boolean {
        return busService_;
    }

    function getError() as String or Null {
        return error_;
    }

    function request(from as String, to as String, numRows as Number, timeOffset as Number or Null) as Void {
        if (pending_) {
            Log.println("Ignoring request, already pending");
            return;
        }
        Log.println("Requesting " + from + " -> " + to);
        pending_     = true;
        isRetry_    = false;
        busService_  = false;
        error_       = null;
        pendingFrom_ = from;
        _makeFilteredRequest(from, to, numRows, timeOffset);
    }

    function onReceive(responseCode as Number, data as Dictionary?) as Void {
        if (responseCode != 200) {
            var message = (data != null && data.hasKey("Message")) ? data.get("Message") as String : null;
            Log.println("HTTP error: " + responseCode + (message != null ? ": " + message : ""));
            error_ = _decodeError(responseCode, message);
            pending_ = false;
            trains_  = new Array<Train>[0];
            onDataChanged_.invoke();
            return;
        }

        if (data == null) {
            error_   = "[No data]";
            pending_ = false;
            trains_  = new Array<Train>[0];
            onDataChanged_.invoke();
            return;
        }

        // First attempt: try trainServices, fall back to busServices.
        // Retry attempt: skip trainServices, go straight to busServices (unfiltered).
        var services = data.get(isRetry_ ? "busServices" : "trainServices");
        busService_ = isRetry_ && (services != null);

        if (services == null) {
            if (!isRetry_) {
                Log.println("No filtered services, retrying for replacement buses");
                isRetry_ = true;
                _makeUnfilteredRequest(pendingFrom_);
                return;
            }
            Log.println("No services found");
            pending_ = false;
            trains_  = new Array<Train>[0];
            onDataChanged_.invoke();
            return;
        }

        pending_ = false;
        trains_  = _parseServices(services as JsonArray);
        onDataChanged_.invoke();
    }

    private function _parseServices(raw as JsonArray) as Array<Train> {
        var size   = raw.size();
        var result = new Array<Train>[size];
        for (var i = 0; i < size; i++) {
            var svc = raw[i] as Dictionary;
            if (svc.hasKey("std") && svc.hasKey("etd")) {
                result[i] = new Train(svc["std"] as String, svc["etd"] as String);
            } else {
                result[i] = new Train("???", "???");
            }
        }
        return result;
    }

    // Match on the API message rather than the status code so we only show
    // "[Bad stop code]" when the server explicitly tells us the CRS is invalid.
    // (HTTP errors via the phone/BLE proxy can also arrive as negative codes,
    // e.g. 400 becomes -400, so status-code matching alone is unreliable.)
    private function _decodeError(responseCode as Number, message as String?) as String {
        if (message != null && message.equals("Invalid crs code supplied")) {
            return "[Bad stop code]";
        }
        switch (responseCode) {
            case Communications.BLE_CONNECTION_UNAVAILABLE:   return "[No Bluetooth]";
            case Communications.BLE_HOST_TIMEOUT:               return "[Phone timeout]";
            case Communications.BLE_SERVER_TIMEOUT:
            case Communications.NETWORK_REQUEST_TIMED_OUT:      return "[No Network]";
            case Communications.NETWORK_RESPONSE_TOO_LARGE:     return "[Too much data]";
            case Communications.NETWORK_RESPONSE_OUT_OF_MEMORY: return "[Low memory]";
        }
        return "[Error " + responseCode + "]";
    }

    private function _makeFilteredRequest(from as String, to as String, numRows as Number, timeOffset as Number or Null) as Void {
        var params = {
            "numRows"   => numRows.toString(),
            "filterCrs" => to
        };
        if (timeOffset != null) {
            params["timeOffset"] = (timeOffset as Number).toString();
        }
        _makeWebRequest(from, params);
    }

    private function _makeUnfilteredRequest(from as String) as Void {
        _makeWebRequest(from, {
            "numRows" => "5"
        });
    }

    private function _makeWebRequest(from as String, params as Dictionary) as Void {
        requester_.get(WebRequester.departureUrl(from), params, method(:onReceive));
    }
}
