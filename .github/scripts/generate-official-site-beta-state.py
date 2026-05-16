import json
import os
import subprocess
import urllib.request
from datetime import datetime, timezone

release_repo = os.environ["RELEASE_REPO"]
release_tag = os.environ["RELEASE_TAG"]
ios_testflight_public_url = os.environ.get("IOS_TESTFLIGHT_PUBLIC_URL", "").strip()
mirror_lines = [
    line.strip()
    for line in os.environ.get("OFFICIAL_SITE_GITHUB_MIRROR_BASES", "").splitlines()
    if line.strip()
]
if not mirror_lines:
    mirror_lines = [
        "国内镜像 1|https://mirror.ghproxy.com/https://github.com/",
        "国内镜像 2|https://ghfast.top/https://github.com/",
    ]

release = json.loads(
    subprocess.check_output(
        ["gh", "api", f"repos/{release_repo}/releases/tags/{release_tag}"],
        text=True,
    )
)

assets = release.get("assets", [])
screenshots = {}


def extract_summary(body, fallback):
    text = body or ""
    marker = "## Included changes"
    if marker in text:
        tail = text.split(marker, 1)[1]
        section = tail.split("\n## ", 1)[0]
    else:
        section = text
    lines = []
    for raw_line in section.splitlines():
        line = raw_line.strip()
        if line.startswith("- "):
            cleaned = line[2:].strip()
            if cleaned:
                lines.append(cleaned)
    return lines[:6] if lines else [fallback]


releases_list = []
try:
    all_releases = json.loads(
        subprocess.check_output(
            ["gh", "api", f"repos/{release_repo}/releases?per_page=5"],
            text=True,
        )
    )
    for rel in all_releases:
        if rel.get("draft"):
            continue
        rel_summary = extract_summary(rel.get("body"), rel.get("name") or rel.get("tag_name"))
        releases_list.append(
            {
                "tag": rel["tag_name"],
                "title": rel.get("name") or rel["tag_name"],
                "publishedAt": rel.get("published_at"),
                "htmlUrl": rel.get("html_url") or f"https://github.com/{release_repo}/releases/tag/{rel['tag_name']}",
                "summary": rel_summary,
            }
        )
except Exception:
    pass

apk_assets = [asset for asset in assets if asset.get("name", "").endswith(".apk")]
apk_asset = next((asset for asset in apk_assets if "arm64" in asset.get("name", "")), apk_assets[0]) if apk_assets else None


def build_mirror_links(primary_href):
    prefix = "https://github.com/"
    if not primary_href.startswith(prefix):
        return []
    path = primary_href[len(prefix):]
    result = []
    for line in mirror_lines:
        label, separator, mirror_prefix = line.partition("|")
        if not separator or not label.strip() or not mirror_prefix.strip():
            continue
        result.append({"label": label.strip(), "href": f"{mirror_prefix.strip()}{path}"})
    return result


testflight_status = {}
testflight_asset = next((asset for asset in assets if asset.get("name") == "TESTFLIGHT_UPLOAD_STATUS.txt"), None)
if testflight_asset:
    with urllib.request.urlopen(testflight_asset["browser_download_url"]) as response:
        content = response.read().decode("utf-8")
    for raw_line in content.splitlines():
        key, separator, value = raw_line.partition("=")
        if separator and key.strip():
            testflight_status[key.strip()] = value.strip()

summary = extract_summary(release.get("body"), release.get("name") or release_tag)
release_url = release.get("html_url") or f"https://github.com/{release_repo}/releases/tag/{release_tag}"

channels = []
notes = []

if apk_asset:
    channels.append(
        {
            "platform": "Android",
            "audience": "beta",
            "status": "Beta 自动同步",
            "title": "Android Beta",
            "description": "官网直接读取最新发布版本的 APK 安装包，安装包发布后这里会自动更新。",
            "primaryLabel": "下载 Android Beta",
            "primaryHref": apk_asset["browser_download_url"],
            "version": release_tag,
            "publishedAt": release.get("published_at"),
            "updateSummary": summary,
            "mirrorLinks": build_mirror_links(apk_asset["browser_download_url"]),
            "note": "国内访问较慢时，可以优先尝试镜像下载入口。",
            "releasePageHref": release_url,
        }
    )
    notes.append("Android beta 下载链接来自本次发布中的 APK 资产。")
    notes.append("镜像链接面向国内网络环境准备，如镜像暂时不可用请使用原始下载地址。")

if testflight_status:
    tf_status = testflight_status.get("status", "")
    tf_uploaded_at = testflight_status.get("uploaded_at") or release.get("published_at")
    tf_build_number = testflight_status.get("build_number") or release_tag
    tf_uploaded = tf_status == "uploaded"
    ios_primary_href = ios_testflight_public_url if tf_uploaded and ios_testflight_public_url else release_url
    ios_primary_label = "加入 iOS TestFlight" if tf_uploaded and ios_testflight_public_url else "查看 iOS 发布状态"
    ios_note = ""
    if tf_uploaded and not ios_testflight_public_url:
        ios_note = "已经上传到 TestFlight，但仓库变量 IOS_TESTFLIGHT_PUBLIC_URL 还没有配置公开加入链接。"
    elif testflight_status.get("reason") == "app_store_connect_credentials_not_configured":
        ios_note = "当前仓库还没有配置 App Store Connect 上传凭据。"
    elif not tf_uploaded:
        ios_note = "当前还没有拿到可公开加入的 TestFlight 入口。"

    channels.append(
        {
            "platform": "iOS",
            "audience": "beta",
            "status": "TestFlight 已开放" if tf_uploaded else "等待 TestFlight 可加入",
            "title": "iOS TestFlight Beta",
            "description": "TestFlight 上传成功后，官网会和 Android beta 一起更新这里的测试入口。",
            "primaryLabel": ios_primary_label,
            "primaryHref": ios_primary_href,
            "version": tf_build_number,
            "publishedAt": tf_uploaded_at,
            "updateSummary": summary,
            "mirrorLinks": [],
            "note": ios_note,
            "releasePageHref": release_url,
        }
    )
    notes.append("iOS TestFlight 入口会在上传状态成功后同步到官网。")
    notes.append("官网展示的 iOS TestFlight 入口来自本次发布携带的上传状态与公开加入链接；如需确认 App Store Connect 后台最终处理态，仍需额外核验。")

if not notes:
    notes.append("本次 release 没有带新的 Android APK 或 iOS TestFlight 状态，官网会继续保留现有渠道信息。")
else:
    notes.append("如果本次 GitHub Release 只带了一个平台，官网会继续保留另一个平台上一版可用信息。")

state = {
    "generatedAt": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
    "release": {
        "tag": release_tag,
        "title": release.get("name") or release_tag,
        "publishedAt": release.get("published_at"),
    },
    "channels": channels,
    "screenshots": screenshots,
    "releases": releases_list,
    "notes": notes,
}

with open("OFFICIAL_SITE_RELEASE_STATE.json", "w", encoding="utf-8") as handle:
    json.dump(state, handle, ensure_ascii=False, indent=2)
    handle.write("\n")
