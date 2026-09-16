# arena_api.api.BookingsApi

## Load the API package
```dart
import 'package:arena_api/api.dart';
```

All URIs are relative to *http://localhost:18080*

Method | HTTP request | Description
------------- | ------------- | -------------
[**cancel**](BookingsApi.md#cancel) | **POST** /api/bookings/{id}/cancel | Cancel a booking as its owner or an administrator before the event starts
[**create1**](BookingsApi.md#create1) | **POST** /api/bookings | Reserve one place at an event
[**get1**](BookingsApi.md#get1) | **GET** /api/bookings/{id} | Read a booking as its owner or an administrator
[**list1**](BookingsApi.md#list1) | **GET** /api/bookings | List your bookings; administrators may request scope&#x3D;all


# **cancel**
> BookingResponse cancel(id)

Cancel a booking as its owner or an administrator before the event starts

### Example
```dart
import 'package:arena_api/api.dart';
// TODO Configure OAuth2 access token for authorization: arenaOAuth
//defaultApiClient.getAuthentication<OAuth>('arenaOAuth').accessToken = 'YOUR_ACCESS_TOKEN';

final api = ArenaApi().getBookingsApi();
final String id = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String |

try {
    final response = api.cancel(id);
    print(response);
} on DioException catch (e) {
    print('Exception when calling BookingsApi->cancel: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **id** | **String**|  |

### Return type

[**BookingResponse**](BookingResponse.md)

### Authorization

[arenaOAuth](../README.md#arenaOAuth)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **create1**
> BookingResponse create1(bookingRequest)

Reserve one place at an event

### Example
```dart
import 'package:arena_api/api.dart';
// TODO Configure OAuth2 access token for authorization: arenaOAuth
//defaultApiClient.getAuthentication<OAuth>('arenaOAuth').accessToken = 'YOUR_ACCESS_TOKEN';

final api = ArenaApi().getBookingsApi();
final BookingRequest bookingRequest = ; // BookingRequest |

try {
    final response = api.create1(bookingRequest);
    print(response);
} on DioException catch (e) {
    print('Exception when calling BookingsApi->create1: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **bookingRequest** | [**BookingRequest**](BookingRequest.md)|  |

### Return type

[**BookingResponse**](BookingResponse.md)

### Authorization

[arenaOAuth](../README.md#arenaOAuth)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **get1**
> BookingResponse get1(id)

Read a booking as its owner or an administrator

### Example
```dart
import 'package:arena_api/api.dart';
// TODO Configure OAuth2 access token for authorization: arenaOAuth
//defaultApiClient.getAuthentication<OAuth>('arenaOAuth').accessToken = 'YOUR_ACCESS_TOKEN';

final api = ArenaApi().getBookingsApi();
final String id = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String |

try {
    final response = api.get1(id);
    print(response);
} on DioException catch (e) {
    print('Exception when calling BookingsApi->get1: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **id** | **String**|  |

### Return type

[**BookingResponse**](BookingResponse.md)

### Authorization

[arenaOAuth](../README.md#arenaOAuth)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **list1**
> BookingPageResponse list1(scope, eventId, status, page, size)

List your bookings; administrators may request scope=all

Defaults to scope=mine, including for administrators. Optional eventId and status filters apply to either scope.

### Example
```dart
import 'package:arena_api/api.dart';
// TODO Configure OAuth2 access token for authorization: arenaOAuth
//defaultApiClient.getAuthentication<OAuth>('arenaOAuth').accessToken = 'YOUR_ACCESS_TOKEN';

final api = ArenaApi().getBookingsApi();
final String scope = scope_example; // String |
final String eventId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String |
final String status = status_example; // String |
final int page = 56; // int | Zero-based page number
final int size = 56; // int | Maximum items per page

try {
    final response = api.list1(scope, eventId, status, page, size);
    print(response);
} on DioException catch (e) {
    print('Exception when calling BookingsApi->list1: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **scope** | **String**|  | [optional] [default to 'mine']
 **eventId** | **String**|  | [optional]
 **status** | **String**|  | [optional]
 **page** | **int**| Zero-based page number | [optional] [default to 0]
 **size** | **int**| Maximum items per page | [optional] [default to 20]

### Return type

[**BookingPageResponse**](BookingPageResponse.md)

### Authorization

[arenaOAuth](../README.md#arenaOAuth)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)
