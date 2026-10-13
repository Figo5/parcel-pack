#!/usr/bin/env python3
"""Create a self-contained iPhone Xcode project without external tooling."""
from pathlib import Path
import hashlib
import json
import argparse
import subprocess

root = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--output-project", type=Path, help="Write a project elsewhere without changing the local checkout")
args = parser.parse_args()
project = args.output_project.resolve() if args.output_project else root / "ParcelPack.xcodeproj"
existing = {}
if project.joinpath("project.pbxproj").exists():
    parsed = subprocess.run(["plutil", "-convert", "json", "-o", "-", str(project / "project.pbxproj")], capture_output=True, check=True)
    existing = json.loads(parsed.stdout).get("objects", {})
project.mkdir(parents=True, exist_ok=True)

def ident(name):
    return hashlib.sha256(name.encode()).hexdigest()[:24].upper()

def q(value):
    return json.dumps(str(value))

objects = []
def obj(name, contents):
    objects.append(f"\t\t{ident(name)} = {{ {contents} }};")
    return ident(name)

source_paths = sorted(root.glob("Sources/ParcelCore/*.swift")) + sorted(root.glob("Sources/ParcelPackApp/*.swift"))
source_refs, source_builds = [], []
for source in source_paths:
    relative = source.relative_to(root).as_posix()
    ref = obj(relative, f"isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {q(relative)}; sourceTree = SOURCE_ROOT;")
    source_refs.append(ref)
    source_builds.append(obj(relative + ":build", f"isa = PBXBuildFile; fileRef = {ref};"))

assets = obj("assets", 'isa = PBXFileReference; lastKnownFileType = folder.assetcatalog; path = Resources/Assets.xcassets; sourceTree = SOURCE_ROOT;')
assets_build = obj("assets-build", f"isa = PBXBuildFile; fileRef = {assets};")
product = obj("product", 'isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = ParcelPack.app; sourceTree = BUILT_PRODUCTS_DIR;')

def array(items):
    return "(" + ", ".join(items) + ",)"

products = obj("products", f"isa = PBXGroup; children = {array([product])}; name = Products; sourceTree = \"<group>\";")
main = obj("main", f"isa = PBXGroup; children = {array(source_refs + [assets, products])}; sourceTree = \"<group>\";")
sources = obj("sources", f"isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = {array(source_builds)}; runOnlyForDeploymentPostprocessing = 0;")
resources = obj("resources", f"isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = {array([assets_build])}; runOnlyForDeploymentPostprocessing = 0;")
frameworks = obj("frameworks", "isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0;")

project_configs, target_configs = [], []
for mode in ("Debug", "Release"):
    project_configs.append(obj("project-" + mode, f'isa = XCBuildConfiguration; name = {mode}; buildSettings = {{ CLANG_ENABLE_MODULES = YES; SDKROOT = iphoneos; IPHONEOS_DEPLOYMENT_TARGET = 17.0; SWIFT_VERSION = 6.0; SWIFT_OPTIMIZATION_LEVEL = {q("-Onone" if mode == "Debug" else "-O")}; DEBUG_INFORMATION_FORMAT = {q("dwarf" if mode == "Debug" else "dwarf-with-dsym")}; }};'))
    settings = {
        "ASSETCATALOG_COMPILER_APPICON_NAME": "AppIcon",
        "CODE_SIGN_STYLE": "Automatic",
        "CURRENT_PROJECT_VERSION": "4",
        "DEVELOPMENT_TEAM": "",
        "GENERATE_INFOPLIST_FILE": "YES",
        "INFOPLIST_KEY_CFBundleDisplayName": "Parcel Pack",
        "INFOPLIST_KEY_LSApplicationCategoryType": "public.app-category.puzzle-games",
        "INFOPLIST_KEY_UIApplicationSceneManifest_Generation": "YES",
        "INFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents": "YES",
        "INFOPLIST_KEY_UILaunchScreen_Generation": "YES",
        "INFOPLIST_KEY_UISupportedInterfaceOrientations": "UIInterfaceOrientationPortrait",
        "MARKETING_VERSION": "1.3",
        "PRODUCT_BUNDLE_IDENTIFIER": "com.giofiore.parcelpack",
        "PRODUCT_NAME": "$(TARGET_NAME)",
        "SUPPORTED_PLATFORMS": "iphoneos iphonesimulator",
        "SUPPORTS_MACCATALYST": "NO",
        "TARGETED_DEVICE_FAMILY": "1",
        "SWIFT_EMIT_LOC_STRINGS": "YES",
        "SWIFT_STRICT_CONCURRENCY": "complete",
    }
    if mode == "Debug":
        settings["SWIFT_ACTIVE_COMPILATION_CONDITIONS"] = "DEBUG"
    # Retain the user's signing choice when adding source files to their local project.
    local_settings = existing.get(ident("target-" + mode), {}).get("buildSettings", {})
    for key in ("DEVELOPMENT_TEAM", "PRODUCT_BUNDLE_IDENTIFIER", "CODE_SIGN_STYLE", "CODE_SIGN_IDENTITY", "PROVISIONING_PROFILE_SPECIFIER"):
        if key in local_settings:
            settings[key] = local_settings[key]
    build = " ".join(f"{key} = {q(value)};" for key, value in settings.items())
    target_configs.append(obj("target-" + mode, f"isa = XCBuildConfiguration; name = {mode}; buildSettings = {{ {build} }};"))

pc = obj("project-configs", f"isa = XCConfigurationList; buildConfigurations = {array(project_configs)}; defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;")
tc = obj("target-configs", f"isa = XCConfigurationList; buildConfigurations = {array(target_configs)}; defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;")
target = obj("target", f'isa = PBXNativeTarget; buildConfigurationList = {tc}; buildPhases = {array([sources, frameworks, resources])}; buildRules = (); dependencies = (); name = ParcelPack; productName = ParcelPack; productReference = {product}; productType = "com.apple.product-type.application";')
pr = obj("project", f'isa = PBXProject; attributes = {{ BuildIndependentTargetsInParallel = YES; LastSwiftUpdateCheck = 1600; LastUpgradeCheck = 1600; TargetAttributes = {{ {target} = {{ CreatedOnToolsVersion = 16.0; }}; }}; }}; buildConfigurationList = {pc}; compatibilityVersion = "Xcode 14.0"; developmentRegion = en; hasScannedForEncodings = 0; knownRegions = (en, Base); mainGroup = {main}; productRefGroup = {products}; projectDirPath = ""; projectRoot = ""; targets = {array([target])};')
project.joinpath("project.pbxproj").write_text("// !$*UTF8*$!\n{\n\tarchiveVersion = 1;\n\tclasses = {};\n\tobjectVersion = 56;\n\tobjects = {\n" + "\n".join(objects) + f"\n\t}};\n\trootObject = {pr};\n}}\n")
schemes = project / "xcshareddata/xcschemes"
schemes.mkdir(parents=True, exist_ok=True)
reference = f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{target}" BuildableName="ParcelPack.app" BlueprintName="ParcelPack" ReferencedContainer="container:ParcelPack.xcodeproj"/>'
schemes.joinpath("ParcelPack.xcscheme").write_text(f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="1600" version="1.3">
 <BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">{reference}</BuildActionEntry></BuildActionEntries></BuildAction>
 <TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES"><Testables/></TestAction>
 <LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" debugServiceExtension="internal" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0">{reference}</BuildableProductRunnable></LaunchAction>
 <ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0">{reference}</BuildableProductRunnable></ProfileAction>
 <AnalyzeAction buildConfiguration="Debug"/>
 <ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>
''')
print(f"Generated {project} with {len(source_paths)} Swift source files.")
