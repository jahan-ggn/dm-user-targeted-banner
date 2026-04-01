import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import { eq } from "discourse/truth-helpers";

export const ALL_PAGES_EXCLUDED_ROUTES = [
  "account-created.edit-email",
  "account-created.index",
  "account-created.resent",
  "activate-account",
  "full-page-search",
  "invites.show",
  "login",
  "password-reset",
  "signup",
];

const MARKDOWN_LINK_RE = /\[([^\]]+)\]\((https?:\/\/[^)]+)\)/;

function simpleHash(str) {
  let hash = 0;
  for (let i = 0; i < str.length; i++) {
    hash = Math.imul(31, hash) + str.charCodeAt(i) || 0;
  }
  return hash.toString(36);
}

function parseBannerText(raw) {
  if (!raw?.trim()) {
    return [];
  }

  const match = MARKDOWN_LINK_RE.exec(raw);
  if (!match) {
    return [{ type: "text", value: raw }];
  }

  const segments = [];
  const [fullMatch, linkText, linkUrl] = match;
  const matchIndex = match.index;

  if (matchIndex > 0) {
    segments.push({ type: "text", value: raw.slice(0, matchIndex) });
  }

  segments.push({ type: "link", text: linkText, url: linkUrl });

  const tail = raw.slice(matchIndex + fullMatch.length);
  if (tail) {
    segments.push({ type: "text", value: tail });
  }

  return segments;
}

const STORAGE_KEY_PREFIX = "discourse-user-banner-dismissed";

function buildStorageKey(text) {
  return `${STORAGE_KEY_PREFIX}-${simpleHash(text)}`;
}

function isDismissed(text) {
  return localStorage.getItem(buildStorageKey(text)) === "1";
}

function markDismissed(text) {
  localStorage.setItem(buildStorageKey(text), "1");
}

export default class UserTypeBanner extends Component {
  @service currentUser;
  @service router;

  @tracked dismissed = false;

  constructor(owner, args) {
    super(owner, args);

    const meta = this.bannerMeta;

    if (meta.isInsider && settings.insider_banner_dismissable) {
      this.dismissed = isDismissed(meta.rawText);
    }
  }

  get bannerMeta() {
    const user = this.currentUser;

    if (!user) {
      return {
        isInsider: false,
        rawText: settings.anonymous_banner_text,
      };
    }

    const isInsider = user.groups?.some((g) => g.name === "insider");

    return {
      isInsider,
      rawText: isInsider
        ? settings.insider_banner_text
        : settings.member_banner_text,
    };
  }

  get segments() {
    return parseBannerText(this.bannerMeta.rawText);
  }

  get isDismissable() {
    return this.bannerMeta.isInsider && settings.insider_banner_dismissable;
  }

  get isRouteAllowed() {
    const currentRouteName = this.router.currentRouteName;

    return (
      !currentRouteName?.startsWith("admin") &&
      !ALL_PAGES_EXCLUDED_ROUTES.some(
        (routeName) => routeName === currentRouteName
      )
    );
  }

  get shouldShow() {
    return this.isRouteAllowed && this.segments.length > 0 && !this.dismissed;
  }

  @action
  dismiss() {
    markDismissed(this.bannerMeta.rawText);
    this.dismissed = true;
  }

  <template>
    {{#if this.shouldShow}}
      <div class="user-type-banner" role="banner">
        <span class="user-type-banner__text">
          {{#each this.segments as |segment|}}
            {{#if (eq segment.type "link")}}
              <a href={{segment.url}} target="_blank" rel="noopener noreferrer">
                {{segment.text}}
              </a>
            {{else}}
              {{segment.value}}
            {{/if}}
          {{/each}}
        </span>

        {{#if this.isDismissable}}
          <DButton
            @action={{this.dismiss}}
            @icon="xmark"
            class="user-type-banner__dismiss btn-transparent"
          />
        {{/if}}
      </div>
    {{/if}}
  </template>
}
