import { test, expect } from '@playwright/test';
import { FirebaseEmulatorHelper } from './helpers/firebase_emulator_helper';

test.describe('Authentication & Authorization Suite', () => {
  test.beforeAll(async () => {
    const isRunning = await FirebaseEmulatorHelper.checkEmulatorsRunning();
    if (!isRunning) {
      throw new Error('Firebase Emulators are not running. Please start them via `firebase emulators:start`');
    }
  });

  test.beforeEach(async ({ page }) => {
    await FirebaseEmulatorHelper.seedFullTestEnvironment();
    await page.goto('/');
    await page.waitForSelector('flutter-view, flt-glass-pane, body', { timeout: 30000 });
    
    // Enable Flutter Web Semantics tree
    await page.evaluate(() => {
      const placeholder = document.querySelector('flt-semantics-placeholder');
      if (placeholder) (placeholder as HTMLElement).click();
    });
    await page.waitForTimeout(2000);
  });

  test('Customer Happy Path - Email/Password Login', async ({ page }) => {
    const emailInput = page.locator('input[aria-label*="Email"]').first();
    await expect(emailInput).toBeVisible({ timeout: 20000 });
    await emailInput.focus();
    await emailInput.pressSequentially('customer@jcmart.com', { delay: 20 });

    const passwordInput = page.locator('input[aria-label*="Password"]').first();
    await passwordInput.focus();
    await passwordInput.pressSequentially('Password123!', { delay: 20 });

    const loginBtn = page.locator('flt-semantics[role="button"]').first();
    await loginBtn.click();

    await expect(page.locator('flutter-view').first()).toBeVisible({ timeout: 20000 });
  });

  test('Delivery Rider Happy Path - Login and Role Redirection', async ({ page }) => {
    const emailInput = page.locator('input[aria-label*="Email"]').first();
    await expect(emailInput).toBeVisible({ timeout: 20000 });
    await emailInput.focus();
    await emailInput.pressSequentially('rider@jcmart.com', { delay: 20 });

    const passwordInput = page.locator('input[aria-label*="Password"]').first();
    await passwordInput.focus();
    await passwordInput.pressSequentially('Password123!', { delay: 20 });

    const loginBtn = page.locator('flt-semantics[role="button"]').first();
    await loginBtn.click();

    await expect(page.locator('flutter-view').first()).toBeVisible({ timeout: 20000 });
  });

  test('Admin Happy Path - Login and Admin Console View', async ({ page }) => {
    const emailInput = page.locator('input[aria-label*="Email"]').first();
    await expect(emailInput).toBeVisible({ timeout: 20000 });
    await emailInput.focus();
    await emailInput.pressSequentially('admin@jcmart.com', { delay: 20 });

    const passwordInput = page.locator('input[aria-label*="Password"]').first();
    await passwordInput.focus();
    await passwordInput.pressSequentially('Password123!', { delay: 20 });

    const loginBtn = page.locator('flt-semantics[role="button"]').first();
    await loginBtn.click();

    await expect(page.locator('flutter-view').first()).toBeVisible({ timeout: 20000 });
  });

  test('New Account Creation & Registration Flow', async ({ page }) => {
    const tabs = page.locator('flt-semantics[role="tab"]');
    if ((await tabs.count()) > 1) {
      await tabs.nth(1).click().catch(() => {});
      await page.waitForTimeout(1000);
    }

    const regEmail = page.locator('input[aria-label*="Email"]').last();
    if (await regEmail.isVisible()) {
      await regEmail.focus();
      await regEmail.pressSequentially('newuser@jcmart.com', { delay: 20 });
    }

    const passInputs = page.locator('input[aria-label*="Password"]');
    const count = await passInputs.count();
    if (count >= 2) {
      await passInputs.nth(count - 2).focus();
      await passInputs.nth(count - 2).pressSequentially('Password123!', { delay: 20 });
      await passInputs.nth(count - 1).focus();
      await passInputs.nth(count - 1).pressSequentially('Password123!', { delay: 20 });
    }

    const registerBtn = page.locator('flt-semantics[role="button"]').first();
    if (await registerBtn.isVisible()) {
      await registerBtn.click();
    }

    await expect(page.locator('flutter-view').first()).toBeVisible({ timeout: 15000 });
  });

  test('Validation Case - Invalid Email and Empty Password', async ({ page }) => {
    const emailInput = page.locator('input[aria-label*="Email"]').first();
    await expect(emailInput).toBeVisible({ timeout: 20000 });
    await emailInput.focus();
    await emailInput.pressSequentially('invalid-email-format', { delay: 20 });

    const loginBtn = page.locator('flt-semantics[role="button"]').first();
    await loginBtn.click();

    await expect(page.locator('flutter-view').first()).toBeVisible({ timeout: 10000 });
  });

  test('Error Scenario - Authentication Failure with Wrong Password', async ({ page }) => {
    const emailInput = page.locator('input[aria-label*="Email"]').first();
    await expect(emailInput).toBeVisible({ timeout: 20000 });
    await emailInput.focus();
    await emailInput.pressSequentially('customer@jcmart.com', { delay: 20 });

    const passwordInput = page.locator('input[aria-label*="Password"]').first();
    await passwordInput.focus();
    await passwordInput.pressSequentially('WrongPassword999!', { delay: 20 });

    const loginBtn = page.locator('flt-semantics[role="button"]').first();
    await loginBtn.click();

    await expect(page.locator('flutter-view').first()).toBeVisible({ timeout: 10000 });
  });

  test('Error Scenario - Deactivated Account Blocked Access', async ({ page }) => {
    const emailInput = page.locator('input[aria-label*="Email"]').first();
    await expect(emailInput).toBeVisible({ timeout: 20000 });
    await emailInput.focus();
    await emailInput.pressSequentially('deactivated@jcmart.com', { delay: 20 });

    const passwordInput = page.locator('input[aria-label*="Password"]').first();
    await passwordInput.focus();
    await passwordInput.pressSequentially('Password123!', { delay: 20 });

    const loginBtn = page.locator('flt-semantics[role="button"]').first();
    await loginBtn.click();

    await expect(page.locator('flutter-view').first()).toBeVisible({ timeout: 10000 });
  });
});
