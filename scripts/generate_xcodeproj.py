#!/usr/bin/env python3
"""Generate Nimbus.xcodeproj without XcodeGen."""
from __future__ import annotations

import hashlib
import os
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PROJECT = ROOT / "Nimbus.xcodeproj"


def pid(name: str) -> str:
    digest = hashlib.sha1(name.encode()).hexdigest()[:24].upper()
    return digest


def collect(rel_dir: str, exts: set[str]) -> list[Path]:
    base = ROOT / rel_dir
    files: list[Path] = []
    for path in sorted(base.rglob("*")):
        if path.is_file() and path.suffix in exts:
            if path.name.endswith(".h"):
                continue
            files.append(path.relative_to(ROOT))
    return files


app_sources = collect("Nimbus", {".swift"}) + collect("NimbusShared", {".swift"})
widget_sources = collect("NimbusWidgets", {".swift"}) + collect("NimbusShared", {".swift"})
resources = [
    Path("Nimbus/Resources/Assets.xcassets"),
]

objects: dict[str, str] = {}


def add(key: str, body: str) -> str:
    objects[key] = body
    return key


# File references
file_refs: dict[str, str] = {}


def file_ref(path: Path, ftype: str | None = None, extra: str = "") -> str:
    key = pid(f"ref:{path}")
    if key in objects:
        return key
    last = path.name
    if ftype is None:
        if path.suffix == ".swift":
            ftype = "sourcecode.swift"
        elif path.suffix == ".plist":
            ftype = "text.plist.xml"
        elif path.suffix == ".entitlements":
            ftype = "text.plist.entitlements"
        elif path.suffix == ".xcassets":
            ftype = "folder.assetcatalog"
        else:
            ftype = "text"
    add(
        key,
        f'isa = PBXFileReference; lastKnownFileType = {ftype}; name = {quote(last)}; path = {quote(str(path))}; sourceTree = SOURCE_ROOT; {extra}',
    )
    file_refs[str(path)] = key
    return key


def quote(value: str) -> str:
    if all(c.isalnum() or c in "._-" for c in value) and value:
        return value
    escaped = value.replace("\\", "\\\\").replace('"', '\\"')
    return f'"{escaped}"'


def build_file(path: Path, prefix: str) -> str:
    ref = file_ref(path)
    key = pid(f"build:{prefix}:{path}")
    add(key, f"isa = PBXBuildFile; fileRef = {ref};")
    return key


# Known refs
app_plist = file_ref(Path("Nimbus/Resources/Info.plist"), extra="")
app_ent = file_ref(Path("Nimbus/Resources/Nimbus.entitlements"))
widget_plist = file_ref(Path("NimbusWidgets/Info.plist"))
widget_ent = file_ref(Path("NimbusWidgets/NimbusWidgets.entitlements"))
app_product = add(
    pid("product:Nimbus.app"),
    'isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = Nimbus.app; sourceTree = BUILT_PRODUCTS_DIR;',
)
widget_product = add(
    pid("product:NimbusWidgets.appex"),
    'isa = PBXFileReference; explicitFileType = "wrapper.app-extension"; includeInIndex = 0; path = NimbusWidgets.appex; sourceTree = BUILT_PRODUCTS_DIR;',
)

app_source_builds = [build_file(p, "app") for p in app_sources]
widget_source_builds = [build_file(p, "widget") for p in widget_sources]
asset_build = build_file(Path("Nimbus/Resources/Assets.xcassets"), "app-res")
embed_widget = add(
    pid("embed:widget"),
    f'isa = PBXBuildFile; fileRef = {widget_product}; settings = {{ATTRIBUTES = (RemoveHeadersOnCopy, ); }};',
)

# Groups — flatten by folder
group_children: dict[str, list[str]] = {}


def ensure_group(rel: str) -> str:
    key = pid(f"group:{rel or 'root-src'}")
    if key in objects:
        return key
    name = Path(rel).name if rel else "Sources"
    add(key, "PLACEHOLDER")
    group_children[key] = []
    return key


# We'll rebuild groups simply: one group per top-level folder
def group_for(files: list[Path], name: str) -> str:
    children = []
    for path in files:
        children.append(file_ref(path))
    key = pid(f"group-list:{name}")
    child_s = ", ".join(children)
    add(
        key,
        f'isa = PBXGroup; children = ( {child_s} ); name = {quote(name)}; sourceTree = "<group>";',
    )
    return key


nimbus_group = group_for(collect("Nimbus", {".swift"}), "Nimbus")
shared_group = group_for(collect("NimbusShared", {".swift"}), "NimbusShared")
widget_group = group_for(collect("NimbusWidgets", {".swift"}), "NimbusWidgets")
res_group = group_for(
    [
        Path("Nimbus/Resources/Info.plist"),
        Path("Nimbus/Resources/Nimbus.entitlements"),
        Path("Nimbus/Resources/Assets.xcassets"),
        Path("NimbusWidgets/Info.plist"),
        Path("NimbusWidgets/NimbusWidgets.entitlements"),
    ],
    "Resources",
)
products_group = add(
    pid("group:products"),
    f'isa = PBXGroup; children = ( {app_product}, {widget_product} ); name = Products; sourceTree = "<group>";',
)
main_group = add(
    pid("group:main"),
    f'isa = PBXGroup; children = ( {nimbus_group}, {shared_group}, {widget_group}, {res_group}, {products_group} ); sourceTree = "<group>";',
)

# Frameworks
appkit = add(
    pid("sdk:AppKit"),
    'isa = PBXFileReference; lastKnownFileType = wrapper.framework; name = AppKit.framework; path = System/Library/Frameworks/AppKit.framework; sourceTree = SDKROOT;',
)
widgetkit = add(
    pid("sdk:WidgetKit"),
    'isa = PBXFileReference; lastKnownFileType = wrapper.framework; name = WidgetKit.framework; path = System/Library/Frameworks/WidgetKit.framework; sourceTree = SDKROOT;',
)
swiftui = add(
    pid("sdk:SwiftUI"),
    'isa = PBXFileReference; lastKnownFileType = wrapper.framework; name = SwiftUI.framework; path = System/Library/Frameworks/SwiftUI.framework; sourceTree = SDKROOT;',
)
coreloc = add(
    pid("sdk:CoreLocation"),
    'isa = PBXFileReference; lastKnownFileType = wrapper.framework; name = CoreLocation.framework; path = System/Library/Frameworks/CoreLocation.framework; sourceTree = SDKROOT;',
)
charts = add(
    pid("sdk:Charts"),
    'isa = PBXFileReference; lastKnownFileType = wrapper.framework; name = Charts.framework; path = System/Library/Frameworks/Charts.framework; sourceTree = SDKROOT;',
)

fw_group = add(
    pid("group:fw"),
    f'isa = PBXGroup; children = ( {appkit}, {widgetkit}, {swiftui}, {coreloc}, {charts} ); name = Frameworks; sourceTree = "<group>";',
)
# patch main group to include frameworks — rewrite
objects[main_group] = (
    f'isa = PBXGroup; children = ( {nimbus_group}, {shared_group}, {widget_group}, {res_group}, {fw_group}, {products_group} ); sourceTree = "<group>";'
)

# Build phases
app_sources_phase = add(
    pid("phase:app-src"),
    "isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = ( "
    + ", ".join(app_source_builds)
    + " ); runOnlyForDeploymentPostprocessing = 0;",
)
widget_sources_phase = add(
    pid("phase:widget-src"),
    "isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = ( "
    + ", ".join(widget_source_builds)
    + " ); runOnlyForDeploymentPostprocessing = 0;",
)
app_res_phase = add(
    pid("phase:app-res"),
    f"isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = ( {asset_build} ); runOnlyForDeploymentPostprocessing = 0;",
)
widget_res_phase = add(
    pid("phase:widget-res"),
    "isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = ( ); runOnlyForDeploymentPostprocessing = 0;",
)
app_fw_phase = add(
    pid("phase:app-fw"),
    "isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = ( ); runOnlyForDeploymentPostprocessing = 0;",
)
widget_fw_phase = add(
    pid("phase:widget-fw"),
    "isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = ( ); runOnlyForDeploymentPostprocessing = 0;",
)
embed_phase = add(
    pid("phase:embed"),
    "isa = PBXCopyFilesBuildPhase; buildActionMask = 2147483647; dstPath = \"\"; dstSubfolderSpec = 13; files = ( "
    + embed_widget
    + " ); name = \"Embed Foundation Extensions\"; runOnlyForDeploymentPostprocessing = 0;",
)

# Configs
shared_debug = """
CLANG_ENABLE_MODULES = YES;
CLANG_ENABLE_OBJC_ARC = YES;
COPY_PHASE_STRIP = NO;
DEBUG_INFORMATION_FORMAT = dwarf;
ENABLE_HARDENED_RUNTIME = YES;
ENABLE_TESTABILITY = YES;
GCC_DYNAMIC_NO_PIC = NO;
GCC_OPTIMIZATION_LEVEL = 0;
MACOSX_DEPLOYMENT_TARGET = 15.0;
ONLY_ACTIVE_ARCH = YES;
SDKROOT = macosx;
SWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG;
SWIFT_OPTIMIZATION_LEVEL = "-Onone";
SWIFT_VERSION = 6.0;
SWIFT_STRICT_CONCURRENCY = complete;
CODE_SIGN_STYLE = Automatic;
DEVELOPMENT_TEAM = 7JA9J6994N;
ALWAYS_SEARCH_USER_PATHS = NO;
CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER = YES;
"""

shared_release = """
CLANG_ENABLE_MODULES = YES;
CLANG_ENABLE_OBJC_ARC = YES;
COPY_PHASE_STRIP = NO;
DEBUG_INFORMATION_FORMAT = "dwarf-with-dsym";
ENABLE_HARDENED_RUNTIME = YES;
GCC_OPTIMIZATION_LEVEL = s;
MACOSX_DEPLOYMENT_TARGET = 15.0;
SDKROOT = macosx;
SWIFT_COMPILATION_MODE = wholemodule;
SWIFT_OPTIMIZATION_LEVEL = "-O";
SWIFT_VERSION = 6.0;
SWIFT_STRICT_CONCURRENCY = complete;
CODE_SIGN_STYLE = Automatic;
DEVELOPMENT_TEAM = 7JA9J6994N;
ALWAYS_SEARCH_USER_PATHS = NO;
"""

proj_debug = add(pid("cfg:proj-debug"), f"isa = XCBuildConfiguration; buildSettings = {{ {shared_debug} }}; name = Debug;")
proj_release = add(pid("cfg:proj-release"), f"isa = XCBuildConfiguration; buildSettings = {{ {shared_release} }}; name = Release;")
proj_cfgs = add(
    pid("list:proj"),
    f"isa = XCConfigurationList; buildConfigurations = ( {proj_debug}, {proj_release} ); defaultConfigurationIsVisible = 0; defaultConfigurationName = Debug;",
)

app_settings_common = """
ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
CODE_SIGN_ENTITLEMENTS = Nimbus/Resources/Nimbus.entitlements;
COMBINE_HIDPI_IMAGES = YES;
CURRENT_PROJECT_VERSION = 1;
GENERATE_INFOPLIST_FILE = NO;
INFOPLIST_FILE = Nimbus/Resources/Info.plist;
LD_RUNPATH_SEARCH_PATHS = "$(inherited) @executable_path/../Frameworks";
MARKETING_VERSION = 1.0;
PRODUCT_BUNDLE_IDENTIFIER = app.nimbus.mac;
PRODUCT_NAME = Nimbus;
ENABLE_HARDENED_RUNTIME = YES;
DEVELOPMENT_TEAM = 7JA9J6994N;
CODE_SIGN_STYLE = Automatic;
"""

widget_settings_common = """
CODE_SIGN_ENTITLEMENTS = NimbusWidgets/NimbusWidgets.entitlements;
COMBINE_HIDPI_IMAGES = YES;
CURRENT_PROJECT_VERSION = 1;
GENERATE_INFOPLIST_FILE = NO;
INFOPLIST_FILE = NimbusWidgets/Info.plist;
LD_RUNPATH_SEARCH_PATHS = "$(inherited) @executable_path/../Frameworks @executable_path/../../../../Frameworks";
MARKETING_VERSION = 1.0;
PRODUCT_BUNDLE_IDENTIFIER = app.nimbus.mac.widgets;
PRODUCT_NAME = NimbusWidgets;
SKIP_INSTALL = YES;
ENABLE_HARDENED_RUNTIME = YES;
DEVELOPMENT_TEAM = 7JA9J6994N;
CODE_SIGN_STYLE = Automatic;
"""

app_debug = add(pid("cfg:app-debug"), f"isa = XCBuildConfiguration; buildSettings = {{ {app_settings_common} }}; name = Debug;")
app_release = add(pid("cfg:app-release"), f"isa = XCBuildConfiguration; buildSettings = {{ {app_settings_common} }}; name = Release;")
app_cfgs = add(
    pid("list:app"),
    f"isa = XCConfigurationList; buildConfigurations = ( {app_debug}, {app_release} ); defaultConfigurationIsVisible = 0; defaultConfigurationName = Debug;",
)
widget_debug = add(pid("cfg:wid-debug"), f"isa = XCBuildConfiguration; buildSettings = {{ {widget_settings_common} }}; name = Debug;")
widget_release = add(pid("cfg:wid-release"), f"isa = XCBuildConfiguration; buildSettings = {{ {widget_settings_common} }}; name = Release;")
widget_cfgs = add(
    pid("list:wid"),
    f"isa = XCConfigurationList; buildConfigurations = ( {widget_debug}, {widget_release} ); defaultConfigurationIsVisible = 0; defaultConfigurationName = Debug;",
)

# Targets
widget_target = add(
    pid("target:widgets"),
    f"""isa = PBXNativeTarget;
buildConfigurationList = {widget_cfgs};
buildPhases = ( {widget_sources_phase}, {widget_fw_phase}, {widget_res_phase} );
buildRules = ( );
dependencies = ( );
name = NimbusWidgets;
productName = NimbusWidgets;
productReference = {widget_product};
productType = "com.apple.product-type.app-extension";
""",
)

container = add(
    pid("proxy:widget"),
    f"isa = PBXContainerItemProxy; containerPortal = {pid('project')}; proxyType = 1; remoteGlobalIDString = {widget_target}; remoteInfo = NimbusWidgets;",
)
dependency = add(
    pid("dep:widget"),
    f"isa = PBXTargetDependency; target = {widget_target}; targetProxy = {container};",
)

app_target = add(
    pid("target:app"),
    f"""isa = PBXNativeTarget;
buildConfigurationList = {app_cfgs};
buildPhases = ( {app_sources_phase}, {app_fw_phase}, {app_res_phase}, {embed_phase} );
buildRules = ( );
dependencies = ( {dependency} );
name = Nimbus;
productName = Nimbus;
productReference = {app_product};
productType = "com.apple.product-type.application";
""",
)

project = add(
    pid("project"),
    f"""isa = PBXProject;
attributes = {{ BuildIndependentTargetsInParallel = 1; LastSwiftUpdateCheck = 2600; LastUpgradeCheck = 2600; }};
buildConfigurationList = {proj_cfgs};
compatibilityVersion = "Xcode 15.0";
developmentRegion = en;
hasScannedForEncodings = 0;
knownRegions = ( en, Base );
mainGroup = {main_group};
productRefGroup = {products_group};
projectDirPath = "";
projectRoot = "";
targets = ( {app_target}, {widget_target} );
""",
)

# Scheme
scheme = """<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="2600" version="1.7">
   <BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES">
      <BuildActionEntries>
         <BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">
            <BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="TARGET_APP" BuildableName="Nimbus.app" BlueprintName="Nimbus" ReferencedContainer="container:Nimbus.xcodeproj"/>
         </BuildActionEntry>
      </BuildActionEntries>
   </BuildAction>
   <TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.DebuggerFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES">
      <Testables>
      </Testables>
   </TestAction>
   <LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.DebuggerFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" debugServiceExtension="internal" allowLocationSimulation="YES">
      <BuildableProductRunnable runnableDebuggingMode="0">
         <BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="TARGET_APP" BuildableName="Nimbus.app" BlueprintName="Nimbus" ReferencedContainer="container:Nimbus.xcodeproj"/>
      </BuildableProductRunnable>
   </LaunchAction>
   <ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES">
      <BuildableProductRunnable runnableDebuggingMode="0">
         <BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="TARGET_APP" BuildableName="Nimbus.app" BlueprintName="Nimbus" ReferencedContainer="container:Nimbus.xcodeproj"/>
      </BuildableProductRunnable>
   </ProfileAction>
   <AnalyzeAction buildConfiguration="Debug"/>
   <ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>
""".replace("TARGET_APP", app_target)

# Write pbxproj
sections = {
    "PBXBuildFile": [],
    "PBXContainerItemProxy": [],
    "PBXCopyFilesBuildPhase": [],
    "PBXFileReference": [],
    "PBXFrameworksBuildPhase": [],
    "PBXGroup": [],
    "PBXNativeTarget": [],
    "PBXProject": [],
    "PBXResourcesBuildPhase": [],
    "PBXSourcesBuildPhase": [],
    "PBXTargetDependency": [],
    "XCBuildConfiguration": [],
    "XCConfigurationList": [],
}

for key, body in objects.items():
    isa = body.split("isa = ")[1].split(";")[0].strip()
    sections.setdefault(isa, []).append((key, body))

lines = [
    "// !$*UTF8*$!",
    "{",
    "\tarchiveVersion = 1;",
    "\tclasses = {",
    "\t};",
    "\tobjectVersion = 56;",
    "\tobjects = {",
    "",
]
for isa, items in sections.items():
    if not items:
        continue
    lines.append(f"/* Begin {isa} section */")
    for key, body in items:
        compact = " ".join(body.split())
        lines.append(f"\t\t{key} = {{ {compact} }};")
    lines.append(f"/* End {isa} section */")
    lines.append("")

lines += [
    "\t};",
    f"\trootObject = {pid('project')};",
    "}",
    "",
]

PROJECT.mkdir(exist_ok=True)
(PROJECT / "project.pbxproj").write_text("\n".join(lines))
scheme_dir = PROJECT / "xcshareddata" / "xcschemes"
scheme_dir.mkdir(parents=True, exist_ok=True)
(scheme_dir / "Nimbus.xcscheme").write_text(scheme)
print(f"Wrote {PROJECT}")
print(f"App sources: {len(app_sources)} Widget sources: {len(widget_sources)}")
