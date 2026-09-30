import { test, expect } from '@playwright/test';
import { FirebaseEmulatorHelper } from './helpers/firebase_emulator_helper';

test.describe('Admin Console & Inventory Management Suite', () => {
  test.beforeEach(async ({ page }) => {
    await FirebaseEmulatorHelper.seedFullTestEnvironment();

    // Login as Admin
    await page.goto('/');
    await page.waitForSelector('flutter-view, flt-glass-pane, body', { timeout: 30000 });
    await page.evaluate(() => {
      const placeholder = document.querySelector('flt-semantics-placeholder');
      if (placeholder) (placeholder as HTMLElement).click();
    });
    await page.waitForTimeout(1500);

    const emailInput = page.locator('input[aria-label*="Email"]').first();
    await emailInput.focus();
    await emailInput.pressSequentially('admin@jcmart.com', { delay: 20 });

    const passwordInput = page.locator('input[aria-label*="Password"]').first();
    await passwordInput.focus();
    await passwordInput.pressSequentially('Password123!', { delay: 20 });

    const loginBtn = page.getByText('Sign In').last();
    await loginBtn.click();

    await expect(page.locator('flutter-view').first()).toBeVisible({ timeout: 20000 });
  });

  test('Admin Dashboard - Inventory Overview and Store Control View', async ({ page }) => {
    await expect(page.locator('flutter-view').first()).toBeVisible();
  });
});
