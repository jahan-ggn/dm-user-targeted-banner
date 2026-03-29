import Component from "@glimmer/component";
import { service } from "@ember/service";
import { eq } from "discourse/truth-helpers";

// Matches a single markdown link: [text](url)
const MARKDOWN_LINK_RE = /\[([^\]]+)\]\((https?:\/\/[^)]+)\)/;

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

export default class UserTypeBanner extends Component {
  @service currentUser;

  get segments() {
    const user = this.currentUser;

    if (!user) {
      return parseBannerText(settings.anonymous_banner_text);
    }

    const isInsider = user.groups?.some((g) => g.name === "insider");
    const raw = isInsider
      ? settings.insider_banner_text
      : settings.member_banner_text;

    return parseBannerText(raw);
  }

  <template>
    {{#if this.segments.length}}
      <div class="user-type-banner" role="banner">
        {{#each this.segments as |segment|}}
          {{#if (eq segment.type "link")}}
            <a
              href={{segment.url}}
              target="_blank"
              rel="noopener noreferrer"
            >{{segment.text}}</a>
          {{else}}
            {{segment.value}}
          {{/if}}
        {{/each}}
      </div>
    {{/if}}
  </template>
}
