export interface DisplayChannel {
  platform: "Android" | "iOS";
  audience: "beta" | "stable";
  status: string;
  description: string;
  primaryHref: string;
  mirrorLinks: { label?: string; href: string }[];
  updateSummary: string[];
  note?: string;
}

interface LocalizedCopy {
  zh: string;
  en: string;
}

const TECHNICAL_COPY_PATTERN = /github|自动同步|仓库|app store connect|凭据|发布记录|release|同步|uploaded|upload|asset|api/i;

function fallbackDescription(channel: DisplayChannel): LocalizedCopy {
  if (channel.platform === "Android" && channel.audience === "beta") {
    return {
      zh: "适合希望第一时间体验新功能的用户。",
      en: "Best for people who want the newest features first.",
    };
  }

  if (channel.platform === "iOS" && channel.audience === "beta") {
    return {
      zh: "通过 TestFlight 安装，适合提前体验 iPhone 或 iPad 新版本。",
      en: "Delivered through TestFlight for early access on iPhone or iPad.",
    };
  }

  return {
    zh: "适合更看重稳定安装和日常使用的用户。",
    en: "Best for people who prefer a steadier install path.",
  };
}

function fallbackSummary(channel: DisplayChannel): LocalizedCopy[] {
  if (channel.platform === "Android" && channel.audience === "beta") {
    return [
      {
        zh: "这里会优先显示最新可安装的 Android 测试版本。",
        en: "This section highlights the latest Android beta you can install.",
      },
      {
        zh: "下载较慢时，可以优先尝试镜像入口。",
        en: "If the download is slow, try the mirror links first.",
      },
    ];
  }

  if (channel.platform === "iOS" && channel.audience === "beta") {
    return [
      {
        zh: "iOS 测试版本通过 Apple TestFlight 分发。",
        en: "iOS beta builds are distributed through Apple TestFlight.",
      },
      {
        zh: "入口开放后，点击即可直接加入测试。",
        en: "Once access is open, the button will take you straight into testing.",
      },
    ];
  }

  return [
    {
      zh: "正式版开放后，这里会提供更稳定的安装入口。",
      en: "When stable is ready, this section will provide the steadier install path.",
    },
    {
      zh: "下载前可以先确认版本号和更新时间。",
      en: "You can confirm the version and publish date before downloading.",
    },
  ];
}

export function getUserFacingStatus(channel: DisplayChannel): LocalizedCopy {
  if (channel.platform === "Android" && channel.audience === "beta") {
    return {
      zh: "最新测试版",
      en: "Latest beta",
    };
  }

  if (channel.platform === "iOS" && channel.audience === "beta") {
    if (channel.primaryHref.includes("testflight.apple.com")) {
      return {
        zh: "TestFlight 可加入",
        en: "Join on TestFlight",
      };
    }

    return {
      zh: "等待测试入口",
      en: "Waiting for access",
    };
  }

  if (channel.primaryHref.startsWith("/contact")) {
    return {
      zh: "正式版筹备中",
      en: "Stable coming soon",
    };
  }

  return {
    zh: "正式版可用",
    en: "Stable available",
  };
}

export function getUserFacingDescription(channel: DisplayChannel): LocalizedCopy {
  if (TECHNICAL_COPY_PATTERN.test(channel.description)) {
    return fallbackDescription(channel);
  }

  return {
    zh: channel.description,
    en: channel.description,
  };
}

export function getUserFacingSummary(channel: DisplayChannel): LocalizedCopy[] {
  const summary = channel.updateSummary
    .map((item) => item.trim())
    .filter(Boolean)
    .filter((item) => !TECHNICAL_COPY_PATTERN.test(item))
    .slice(0, 2)
    .map((item) => ({ zh: item, en: item }));

  return summary.length > 0 ? summary : fallbackSummary(channel);
}

export function getUserFacingNote(channel: DisplayChannel): LocalizedCopy | null {
  if (channel.platform === "Android" && channel.mirrorLinks.length > 0) {
    return {
      zh: "下载较慢时，可优先尝试镜像入口。",
      en: "If the download is slow, try the mirror links first.",
    };
  }

  if (channel.platform === "iOS" && channel.audience === "beta") {
    return channel.primaryHref.includes("testflight.apple.com")
      ? {
          zh: "点击后会打开 Apple TestFlight 页面。",
          en: "This button opens the Apple TestFlight page.",
        }
      : {
          zh: "测试资格开放后，这里会显示可加入入口。",
          en: "A join button will appear here once testing access opens.",
        };
  }

  if (channel.note && !TECHNICAL_COPY_PATTERN.test(channel.note)) {
    return {
      zh: channel.note,
      en: channel.note,
    };
  }

  return null;
}
