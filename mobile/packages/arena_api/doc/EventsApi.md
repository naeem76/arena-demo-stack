# arena_api.api.EventsApi

## Load the API package
```dart
import 'package:arena_api/api.dart';
```

All URIs are relative to *http://localhost:18080*

Method | HTTP request | Description
------------- | ------------- | -------------
[**callGet**](EventsApi.md#callget) | **GET** /api/events/{id} | Get event details
[**changeStatus**](EventsApi.md#changestatus) | **PATCH** /api/events/{id}/status | Change event status through an allowed lifecycle transition (admin only)
[**create**](EventsApi.md#create) | **POST** /api/events | Create a scheduled event (admin only)
[**delete**](EventsApi.md#delete) | **DELETE** /api/events/{id} | Delete an event (admin only)
[**list**](EventsApi.md#list) | **GET** /api/events | List events, optionally filtering by sport and status
[**update**](EventsApi.md#update) | **PUT** /api/events/{id} | Replace scheduled event details (admin only)


# **callGet**
> EventResponse callGet(id)

Get event details

### Example
```dart
import 'package:arena_api/api.dart';
// TODO Configure OAuth2 access token for authorization: arenaOAuth
//defaultApiClient.getAuthentication<OAuth>('arenaOAuth').accessToken = 'YOUR_ACCESS_TOKEN';

final api = ArenaApi().getEventsApi();
final String id = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String |

try {
    final response = api.callGet(id);
    print(response);
} on DioException catch (e) {
    print('Exception when calling EventsApi->callGet: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **id** | **String**|  |

### Return type

[**EventResponse**](EventResponse.md)

### Authorization

[arenaOAuth](../README.md#arenaOAuth)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **changeStatus**
> EventResponse changeStatus(id, eventStatusRequest)

Change event status through an allowed lifecycle transition (admin only)

### Example
```dart
import 'package:arena_api/api.dart';
// TODO Configure OAuth2 access token for authorization: arenaOAuth
//defaultApiClient.getAuthentication<OAuth>('arenaOAuth').accessToken = 'YOUR_ACCESS_TOKEN';

final api = ArenaApi().getEventsApi();
final String id = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String |
final EventStatusRequest eventStatusRequest = ; // EventStatusRequest |

try {
    final response = api.changeStatus(id, eventStatusRequest);
    print(response);
} on DioException catch (e) {
    print('Exception when calling EventsApi->changeStatus: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **id** | **String**|  |
 **eventStatusRequest** | [**EventStatusRequest**](EventStatusRequest.md)|  |

### Return type

[**EventResponse**](EventResponse.md)

### Authorization

[arenaOAuth](../README.md#arenaOAuth)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **create**
> EventResponse create(eventRequest)

Create a scheduled event (admin only)

### Example
```dart
import 'package:arena_api/api.dart';
// TODO Configure OAuth2 access token for authorization: arenaOAuth
//defaultApiClient.getAuthentication<OAuth>('arenaOAuth').accessToken = 'YOUR_ACCESS_TOKEN';

final api = ArenaApi().getEventsApi();
final EventRequest eventRequest = ; // EventRequest |

try {
    final response = api.create(eventRequest);
    print(response);
} on DioException catch (e) {
    print('Exception when calling EventsApi->create: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **eventRequest** | [**EventRequest**](EventRequest.md)|  |

### Return type

[**EventResponse**](EventResponse.md)

### Authorization

[arenaOAuth](../README.md#arenaOAuth)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **delete**
> delete(id)

Delete an event (admin only)

### Example
```dart
import 'package:arena_api/api.dart';
// TODO Configure OAuth2 access token for authorization: arenaOAuth
//defaultApiClient.getAuthentication<OAuth>('arenaOAuth').accessToken = 'YOUR_ACCESS_TOKEN';

final api = ArenaApi().getEventsApi();
final String id = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String |

try {
    api.delete(id);
} on DioException catch (e) {
    print('Exception when calling EventsApi->delete: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **id** | **String**|  |

### Return type

void (empty response body)

### Authorization

[arenaOAuth](../README.md#arenaOAuth)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: Not defined

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **list**
> EventPageResponse list(sport, status, page, size)

List events, optionally filtering by sport and status

### Example
```dart
import 'package:arena_api/api.dart';
// TODO Configure OAuth2 access token for authorization: arenaOAuth
//defaultApiClient.getAuthentication<OAuth>('arenaOAuth').accessToken = 'YOUR_ACCESS_TOKEN';

final api = ArenaApi().getEventsApi();
final String sport = sport_example; // String |
final String status = status_example; // String |
final int page = 56; // int | Zero-based page number
final int size = 56; // int | Maximum items per page

try {
    final response = api.list(sport, status, page, size);
    print(response);
} on DioException catch (e) {
    print('Exception when calling EventsApi->list: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **sport** | **String**|  | [optional]
 **status** | **String**|  | [optional]
 **page** | **int**| Zero-based page number | [optional] [default to 0]
 **size** | **int**| Maximum items per page | [optional] [default to 20]

### Return type

[**EventPageResponse**](EventPageResponse.md)

### Authorization

[arenaOAuth](../README.md#arenaOAuth)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **update**
> EventResponse update(id, eventRequest)

Replace scheduled event details (admin only)

### Example
```dart
import 'package:arena_api/api.dart';
// TODO Configure OAuth2 access token for authorization: arenaOAuth
//defaultApiClient.getAuthentication<OAuth>('arenaOAuth').accessToken = 'YOUR_ACCESS_TOKEN';

final api = ArenaApi().getEventsApi();
final String id = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String |
final EventRequest eventRequest = ; // EventRequest |

try {
    final response = api.update(id, eventRequest);
    print(response);
} on DioException catch (e) {
    print('Exception when calling EventsApi->update: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **id** | **String**|  |
 **eventRequest** | [**EventRequest**](EventRequest.md)|  |

### Return type

[**EventResponse**](EventResponse.md)

### Authorization

[arenaOAuth](../README.md#arenaOAuth)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)
