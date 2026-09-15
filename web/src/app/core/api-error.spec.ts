import { HttpErrorResponse } from '@angular/common/http';
import { describe, expect, it } from 'vitest';
import { describeApiError } from './api-error';

describe('describeApiError', () => {
  it('maps validation violations to fields and ignores malformed entries', () => {
    expect(
      describeApiError(
        new HttpErrorResponse({
          status: 400,
          error: {
            detail: 'Please correct the booking details.',
            errors: [
              { field: 'email', message: 'Enter a valid email.' },
              { field: 'quantity', message: 'Choose at least one ticket.' },
              null,
              { field: 'ignored', message: 123 },
              { field: 123, message: 'Invalid' },
            ],
          },
        }),
      ),
    ).toEqual({
      message: 'Please correct the booking details.',
      fields: { email: 'Enter a valid email.', quantity: 'Choose at least one ticket.' },
    });
  });

  it.each([500, 503])(
    'keeps server %s internals out of both the message and field errors',
    (status) => {
      const result = describeApiError(
        new HttpErrorResponse({
          status,
          error: {
            detail: 'SqlException: secret database password at BookingRepository.cs:42',
            stack: 'internal stack trace',
            errors: [{ field: 'database', message: 'secret database password' }],
          },
        }),
      );
      expect(result).toEqual({
        message: 'The server could not complete this request. Please try again.',
        fields: {},
      });
      expect(JSON.stringify(result)).not.toMatch(/SqlException|password|stack|Repository/);
    },
  );

  it('gives actionable network guidance and handles unexpected failures without exposing internals', () => {
    expect(
      describeApiError(
        new HttpErrorResponse({ status: 0, error: new Error('net::ERR_CONNECTION_REFUSED') }),
      ),
    ).toEqual({
      message: 'We could not reach the API. Check your connection and try again.',
      fields: {},
    });
    expect(describeApiError(new Error('private stack details'))).toEqual({
      message: 'Something went wrong. Please try again.',
      fields: {},
    });
    expect(
      describeApiError(new HttpErrorResponse({ status: 400, error: '<html>proxy error</html>' })),
    ).toEqual({
      message: 'The request could not be completed. Check your input and try again.',
      fields: {},
    });
  });

  it.each([
    [401, 'Your session has expired. Sign in again to continue.'],
    [403, 'Your account does not have permission to perform this action.'],
    [404, 'This record could not be found. It may have been removed.'],
  ])(
    'uses status-specific guidance for %s instead of untrusted server detail',
    (status, message) => {
      expect(
        describeApiError(
          new HttpErrorResponse({ status: Number(status), error: { detail: 'internal detail' } }),
        ),
      ).toEqual({ message, fields: {} });
    },
  );
});
