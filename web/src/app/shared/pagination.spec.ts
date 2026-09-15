import { TestBed } from '@angular/core/testing';
import { convertToParamMap } from '@angular/router';
import { Pagination, readPagination } from './pagination';

describe('Pagination', () => {
  afterEach(() => TestBed.resetTestingModule());

  it.each([
    [{}, { page: 0, size: 20 }],
    [
      { page: '-1', size: '0' },
      { page: 0, size: 20 },
    ],
    [
      { page: 'NaN', size: '1.5' },
      { page: 0, size: 20 },
    ],
    [
      { page: '1.5', size: '101' },
      { page: 0, size: 100 },
    ],
    [
      { page: '3', size: '10' },
      { page: 3, size: 10 },
    ],
  ])('normalizes URL pagination %j', (params, expected) => {
    expect(readPagination(convertToParamMap(params))).toEqual(expected);
  });

  it.each(['page', 'eventPage'])('keeps %s within the API integer range', (key) => {
    expect(readPagination(convertToParamMap({ [key]: '2147483647' }), key).page).toBe(2147483647);
    expect(readPagination(convertToParamMap({ [key]: '2147483648' }), key).page).toBe(0);
    expect(readPagination(convertToParamMap({ [key]: '9007199254740991' }), key).page).toBe(0);
  });

  it('renders totals and emits previous/next pages, disabling boundaries and loading', () => {
    const fixture = TestBed.createComponent(Pagination);
    fixture.componentRef.setInput('label', 'Event pages');
    fixture.componentRef.setInput('info', { page: 1, size: 20, totalElements: 41, totalPages: 3 });
    const change = vi.fn();
    fixture.componentInstance.pageChange.subscribe(change);
    fixture.detectChanges();
    const buttons = fixture.nativeElement.querySelectorAll(
      'button',
    ) as NodeListOf<HTMLButtonElement>;
    expect(fixture.nativeElement.textContent).toContain('41 total');
    buttons[0].click();
    buttons[1].click();
    expect(change.mock.calls).toEqual([[0], [2]]);
    fixture.componentRef.setInput('busy', true);
    fixture.detectChanges();
    expect([...buttons].every((button) => button.disabled)).toBe(true);
    fixture.componentRef.setInput('busy', false);
    fixture.componentRef.setInput('info', { page: 0, size: 20, totalElements: 21, totalPages: 2 });
    fixture.detectChanges();
    expect(buttons[0].disabled).toBe(true);
    expect(buttons[1].disabled).toBe(false);
    fixture.componentRef.setInput('info', { page: 1, size: 20, totalElements: 21, totalPages: 2 });
    fixture.detectChanges();
    expect(buttons[0].disabled).toBe(false);
    expect(buttons[1].disabled).toBe(true);
    fixture.componentRef.setInput('info', { page: 0, size: 20, totalElements: 0, totalPages: 0 });
    fixture.detectChanges();
    expect([...buttons].every((button) => button.disabled)).toBe(true);
  });
});
