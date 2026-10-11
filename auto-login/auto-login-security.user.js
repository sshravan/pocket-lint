// ==UserScript==
// @name         Login + security questions + continue
// @match        https://www.[YOU_KNOW]scheduling.com/*
// @match        https://[TENANT_NAME].b2clogin.com/*
// @grant        none
// @run-at       document-idle
// ==/UserScript==

(function () {
    // ---------- CONFIG ----------
    const USERNAME = '[PLACEHOLDER]';
    const PASSWORD = '[PLACEHOLDER]';

    const ANSWERS = {
        "What was your first car?": '[PLACEHOLDER]',
        "What is the name of a college you applied to but didn't attend?": '[PLACEHOLDER]',
        "What is the name of the road/street you grew up on?": '[PLACEHOLDER]',
    };

    const MAX_ATTEMPTS = 2;          // per page type, per tab (avoids lockout if something is wrong)
    const INIT_DELAY_MS = 1000;      // let the page's own scripts finish first
    const CLICK_DELAY_MS = 800;      // pause between filling and clicking
    const log = (...a) => console.log('[AutoAuth]', ...a);

    // ---------- HELPERS ----------
    const normalize = (s) =>
        s.toLowerCase().replace(/['"]/g, "").replace(/\s+/g, ' ').trim();

    const QA = Object.entries(ANSWERS).map(([q, a]) => [normalize(q), a]);

    // Mimic a real user typing into the field
    function setValue(input, value) {
        input.focus();
        input.dispatchEvent(new KeyboardEvent('keydown', { bubbles: true, key: 'a' }));
        const setter = Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, 'value').set;
        setter.call(input, value);
        input.dispatchEvent(new InputEvent('input', { bubbles: true, inputType: 'insertText', data: value }));
        input.dispatchEvent(new KeyboardEvent('keyup', { bubbles: true, key: 'a' }));
        input.dispatchEvent(new Event('change', { bubbles: true }));
        input.dispatchEvent(new Event('blur', { bubbles: true }));
    }

    // The answer box lives in the NEXT <li> after the question's <li>
    function findAnswerInput(questionEl) {
        let li = questionEl.closest('li');
        while (li && (li = li.nextElementSibling)) {
            const input = li.querySelector('input[type="password"], input[type="text"]');
            if (input) return input;
        }
        return null;
    }

    // Both pages use button#continue, so identify it by its label
    function getButton(expectedLabel) {
        const btn = document.querySelector('button#continue');
        if (!btn) return null;
        const label = normalize(btn.getAttribute('aria-label') || btn.textContent || '');
        if (label !== expectedLabel) return null;
        if (btn.disabled || btn.getAttribute('aria-disabled') === 'true') return null;
        return btn;
    }

    // ---------- PAGE HANDLERS ----------
    // Each returns [{input, value}] for the fields it manages, or null if not on this page

    const loginPage = {
        name: 'login',
        buttonLabel: 'sign in',
        fill() {
            const user = document.querySelector('input#signInName');
            const pass = document.querySelector('input#password');
            if (!user || !pass) return null;
            if (user.value !== USERNAME) setValue(user, USERNAME);
            if (pass.value !== PASSWORD) setValue(pass, PASSWORD);
            return [
                { input: user, value: USERNAME },
                { input: pass, value: PASSWORD },
            ];
        },
    };

    const securityPage = {
        name: 'security questions',
        buttonLabel: 'continue',
        fill() {
            const questions = document.querySelectorAll('p.textInParagraph');
            if (!questions.length) return null;
            const targets = [];
            for (const p of questions) {
                const text = normalize(p.textContent);
                const match = QA.find(([q]) => text === q || text.includes(q));
                if (!match) {
                    log('No answer configured for question:', p.textContent.trim());
                    continue;
                }
                const input = findAnswerInput(p);
                if (!input) continue;
                if (input.value !== match[1]) setValue(input, match[1]);
                targets.push({ input, value: match[1] });
            }
            return targets.length ? targets : null;
        },
    };

    const PAGES = [loginPage, securityPage];
    const busy = {};

    function run() {
        for (const page of PAGES) {
            if (busy[page.name]) continue;

            const targets = page.fill();
            if (!targets) continue; // not this page

            const key = 'autoAuthAttempts:' + page.name;
            const attempts = Number(sessionStorage.getItem(key) || 0);
            if (attempts >= MAX_ATTEMPTS) {
                log(`Paused (${page.name}): max attempts reached in this tab.`);
                continue;
            }

            busy[page.name] = true;
            log(`Filled ${targets.length} field(s) on ${page.name} page, clicking shortly...`);

            setTimeout(() => {
                // Re-fill right before clicking in case the page cleared anything
                const again = page.fill();
                const ok = again && again.length === targets.length &&
                    again.every((t) => t.input.value === t.value);
                log('Field lengths before click:', again ? again.map((t) => t.input.value.length) : null);

                if (!ok) {
                    log('A field was empty or changed, retrying instead of clicking.');
                    busy[page.name] = false;
                    return;
                }

                const btn = getButton(page.buttonLabel);
                if (btn) {
                    sessionStorage.setItem(key, String(attempts + 1));
                    log(`Clicking "${page.buttonLabel}"`);
                    btn.click();
                } else {
                    log('Button missing or disabled.');
                    busy[page.name] = false;
                }
            }, CLICK_DELAY_MS);
            return; // handle one page type at a time
        }
    }

    setTimeout(() => {
        new MutationObserver(run).observe(document.body, { childList: true, subtree: true });
        run();
    }, INIT_DELAY_MS);
})();
