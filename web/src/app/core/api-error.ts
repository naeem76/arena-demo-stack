import { HttpErrorResponse } from '@angular/common/http';

export interface ApiError {
  message: string;
  fields: Record<string, string>;
}

export function describeApiError(error: unknown): ApiError {
  const fields: Record<string, string> = {};
  if (!(error instanceof HttpErrorResponse)) {
    return { message: 'Something went wrong. Please try again.', fields };
  }
  if (error.status === 0)
    return { message: 'We could not reach the API. Check your connection and try again.', fields };
  if (error.status === 401)
    return { message: 'Your session has expired. Sign in again to continue.', fields };
  if (error.status === 403)
    return { message: 'Your account does not have permission to perform this action.', fields };
  if (error.status === 404)
    return { message: 'This record could not be found. It may have been removed.', fields };
  if (error.status >= 500)
    return { message: 'The server could not complete this request. Please try again.', fields };

  // A bodyless operation uses responseType=text, including for its JSON errors.
  let body = error.error;
  if (typeof body === 'string') {
    try {
      body = JSON.parse(body);
    } catch {
      body = undefined;
    }
  }
  if (body && typeof body === 'object' && Array.isArray(body.errors)) {
    for (const violation of body.errors) {
      if (typeof violation?.field === 'string' && typeof violation?.message === 'string') {
        fields[violation.field] = violation.message;
      }
    }
  }
  return {
    message:
      typeof body?.detail === 'string'
        ? body.detail
        : 'The request could not be completed. Check your input and try again.',
    fields,
  };
}
