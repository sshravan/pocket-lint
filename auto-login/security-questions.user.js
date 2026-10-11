// ==UserScript==
// @name         Security questions + continue
// @match        https://www.[YOU_KNOW]scheduling.com/*
// @match        https://[TENANT_NAME].b2clogin.com/*
// @grant        none
// @run-at       document-idle
// ==/UserScript==

(function () {
    const ANSWERS = {
        'What was your first car?': '[PLACEHOLDER]',
        'What is the name of a college you applied to but didn\'t attend?': '[PLACEHOLDER]',
        'What is the name of the road/street you grew up on?': '[PLACEHOLDER]',
    };

    const MAX_ATTEMPTS = 2;         // stops auto-clicking if answers are wrong
    const INIT_DELAY_MS = 1000;     // let the page's own scripts finish first
    const CLICK_DELAY_MS = 800;     // pause between filling and clicking
    const ATTEMPT_KEY = 'secQAttempts';
    const log = (...a) => console.log('[SecQ]', ...a);

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

    // Fills every known question; returns [{input, answer}] for the ones found
    function fillAll() {
        const targets = [];
        for (const p of document.querySelectorAll('p.textInParagraph')) {
            const text = normalize(p.textContent);
            const match = QA.find(([q]) => text === q || text.includes(q));
            if (!match) {
                log('No answer configured for question:', p.textContent.trim());
                continue;
            }
            const input = findAnswerInput(p);
            if (!input) continue;
            if (input.value !== match[1]) setValue(input, match[1]);
            targets.push({ input, answer: match[1] });
        }
        return targets;
    }

    let busy = false;

    function run() {
        if (busy) return;
        const targets = fillAll();
        if (targets.length === 0) return;

        const attempts = Number(sessionStorage.getItem(ATTEMPT_KEY) || 0);
        if (attempts >= MAX_ATTEMPTS) {
            log('Paused: max attempts reached in this tab.');
            return;
        }

        busy = true;
        log(`Filled ${targets.length} field(s), clicking Continue shortly...`);

        setTimeout(() => {
            // Re-fill right before clicking in case the page cleared anything
            const again = fillAll();
            const allFilled = again.length > 0 && again.every((t) => t.input.value === t.answer);
            log('Field lengths before click:', again.map((t) => t.input.value.length));

            if (!allFilled) {
                log('A field was empty or changed, retrying instead of clicking.');
                busy = false;
                return;
            }

            const btn = document.querySelector('button#continue');
            if (btn && !btn.disabled && btn.getAttribute('aria-disabled') !== 'true') {
                sessionStorage.setItem(ATTEMPT_KEY, String(attempts + 1));
                log('Clicking Continue');
                btn.click();
            } else {
                log('Continue button missing or disabled.');
                busy = false;
            }
        }, CLICK_DELAY_MS);
    }

    setTimeout(() => {
        new MutationObserver(run).observe(document.body, { childList: true, subtree: true });
        run();
    }, INIT_DELAY_MS);
})();
