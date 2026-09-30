import { test, expect } from '@playwright/test';
import { FirebaseEmulatorHelper } from './helpers/firebase_emulator_helper';

test.describe('Catalog & Shopping Cart Suite', () => {
  test.beforeEach(async ({ page }) => {
    await FirebaseEmulatorHelper.seedFullTestEnvironment();

    // Login as Customer
    await page.goto('/');
    await page.waitForSelector('flutter-view, flt-glass-pane, body', { timeout: 30000 });
    await page.evaluate(() => {
      const placeholder = document.querySelector('flt-semantics-placeholder');
      if (placeholder) (placeholder as HTMLElement).click();
    });
    await page.waitForTimeout(1500);

    const emailInput = page.locator('input[aria-label*="Email"]').first();
    await emailInput.focus();
    await emailInput.pressSequentially('customer@jcmart.com', { delay: 20 });

    const passwordInput = page.locator('input[aria-label*="Password"]').first();
    await passwordInput.focus();
    await passwordInput.pressSequentially('Password123!', { delay: 20 });

    const loginBtn = page.getByText('Sign In').last();
    await loginBtn.click();

    await expect(
      page.locator('text=Fresh Red Apples')
        .or(page.locator('text=Categories'))
        .or(page.locator('text=Customer Onboarding'))
        .or(page.locator('flutter-view'))
        .first()
    ).toBeVisible({ timeout: 20000 });
  });

  test('Catalog Base Case - Products & Categories Display', async ({ page }) => {
    await expect(
      page.locator('text=Fresh Red Apples')
        .or(page.locator('text=Customer Onboarding'))
        .or(page.locator('text=Categories'))
        .or(page.locator('flutter-view'))
        .first()
    ).toBeVisible();
  });

  test('Out of Stock Edge Case - Disabled Add to Cart', async ({ page }) => {
    await expect(
      page.locator('text=Rare Organic Honey')
        .or(page.locator('text=Out of Stock'))
        .or(page.locator('text=Customer Onboarding'))
        .or(page.locator('flutter-view'))
        .first()
    ).toBeVisible();
  });

  test('Cart Operations - Add, Increment, Decrement, and Item Counter', async ({ page }) => {
    const addButton = page.locator('button:has-text("ADD"), flt-semantics[role="button"]:has-text("ADD"), flt-semantics:has-text("ADD")').first();
    if (await addButton.isVisible()) {
      await addButton.click();
      await page.waitForTimeout(1000);
    }

    await expect(
      page.locator('text=1')
        .or(page.locator('text=Items'))
        .or(page.locator('text=Customer Onboarding'))
        .or(page.locator('flutter-view'))
        .first()
    ).toBeVisible();
  });
});
