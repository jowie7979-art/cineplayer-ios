"""Schrijft CinePlayer.xcodeproj (SwiftUI, geen Mac nodig).

De bronmap `CinePlayer/` is gesynchroniseerd (objectVersion 77): elk bestand
dat erin staat doet vanzelf mee.
gebruik: python Native/hulp/maak_project.py
"""
import os

HIER = os.path.dirname(os.path.abspath(__file__))
PROJ = os.path.join(HIER, '..', 'CinePlayer.xcodeproj')

PROJECT, MAIN_GROUP, PRODUCTS, PRODUCT, SYNC, TARGET = (
    'C1E0000000000000000000%02X' % i for i in range(1, 7))
SOURCES, FRAMEWORKS, RESOURCES = ('C1E0000000000000000000%02X' % i for i in range(7, 10))
PROJ_LIST, PROJ_DEBUG, PROJ_RELEASE, DOEL_LIST, DOEL_DEBUG, DOEL_RELEASE = (
    'C1E0000000000000000000%02X' % i for i in range(10, 16))

VERSIE = '2.0'

GEMEEN = [
    'ALWAYS_SEARCH_USER_PATHS = NO;',
    'ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS = YES;',
    'CLANG_ENABLE_MODULES = YES;',
    'CLANG_ENABLE_OBJC_ARC = YES;',
    'COPY_PHASE_STRIP = NO;',
    'ENABLE_STRICT_OBJC_MSGSEND = YES;',
    'ENABLE_USER_SCRIPT_SANDBOXING = YES;',
    'GCC_C_LANGUAGE_STANDARD = gnu17;',
    'GCC_NO_COMMON_BLOCKS = YES;',
    'IPHONEOS_DEPLOYMENT_TARGET = 26.0;',
    'LOCALIZATION_PREFERS_STRING_CATALOGS = YES;',
    'SDKROOT = iphoneos;',
]
DEBUG = [
    'DEBUG_INFORMATION_FORMAT = dwarf;',
    'ENABLE_TESTABILITY = YES;',
    'GCC_OPTIMIZATION_LEVEL = 0;',
    'ONLY_ACTIVE_ARCH = YES;',
    'SWIFT_ACTIVE_COMPILATION_CONDITIONS = "DEBUG $(inherited)";',
    'SWIFT_OPTIMIZATION_LEVEL = "-Onone";',
]
RELEASE = [
    'DEBUG_INFORMATION_FORMAT = "dwarf-with-dsym";',
    'ENABLE_NS_ASSERTIONS = NO;',
    'SWIFT_COMPILATION_MODE = wholemodule;',
    'VALIDATE_PRODUCT = YES;',
]
DOEL = [
    'ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;',
    'ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor;',
    'CODE_SIGN_STYLE = Automatic;',
    'CURRENT_PROJECT_VERSION = 1;',
    'ENABLE_PREVIEWS = YES;',
    'GENERATE_INFOPLIST_FILE = YES;',
    'INFOPLIST_KEY_CFBundleDisplayName = CinePlayer;',
    'INFOPLIST_KEY_ITSAppUsesNonExemptEncryption = NO;',
    'INFOPLIST_KEY_LSApplicationCategoryType = "public.app-category.entertainment";',
    'INFOPLIST_KEY_UIApplicationSceneManifest_Generation = YES;',
    'INFOPLIST_KEY_UILaunchScreen_Generation = YES;',
    'INFOPLIST_KEY_UIStatusBarStyle = UIStatusBarStyleLightContent;',
    'INFOPLIST_KEY_UISupportedInterfaceOrientations = '
    '"UIInterfaceOrientationPortrait UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight";',
    'LD_RUNPATH_SEARCH_PATHS = (\n\t\t\t\t\t"$(inherited)",\n\t\t\t\t\t"@executable_path/Frameworks",\n\t\t\t\t);',
    'MARKETING_VERSION = %s;' % VERSIE,
    'PRODUCT_BUNDLE_IDENTIFIER = nl.jawad.cineplayer;',
    'PRODUCT_NAME = "$(TARGET_NAME)";',
    'SWIFT_EMIT_LOC_STRINGS = YES;',
    'SWIFT_VERSION = 5.0;',
    'TARGETED_DEVICE_FAMILY = 1;',
]


def instellingen(regels):
    return ''.join('\t\t\t\t' + r + '\n' for r in sorted(regels, key=lambda r: r.split(' =')[0]))


def config(id_, naam, regels):
    return ('\t\t%s /* %s */ = {\n\t\t\tisa = XCBuildConfiguration;\n\t\t\tbuildSettings = {\n%s\t\t\t};\n'
            '\t\t\tname = %s;\n\t\t};\n' % (id_, naam, instellingen(regels), naam))


def lijst(items):
    return ''.join('\t\t\t\t%s,\n' % i for i in items)


def fase(id_, soort, naam):
    return ('\t\t%s /* %s */ = {\n\t\t\tisa = %s;\n\t\t\tbuildActionMask = 2147483647;\n\t\t\tfiles = (\n\t\t\t);\n'
            '\t\t\trunOnlyForDeploymentPostprocessing = 0;\n\t\t};\n' % (id_, naam, soort))


t = []
w = t.append
w('// !$*UTF8*$!\n{\n\tarchiveVersion = 1;\n\tclasses = {\n\t};\n\tobjectVersion = 77;\n\tobjects = {\n\n')
w('/* Begin PBXFileReference section */\n')
w('\t\t%s /* CinePlayer.app */ = {isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; '
  'path = CinePlayer.app; sourceTree = BUILT_PRODUCTS_DIR; };\n' % PRODUCT)
w('/* End PBXFileReference section */\n\n')
w('/* Begin PBXFileSystemSynchronizedRootGroup section */\n')
w('\t\t%s /* CinePlayer */ = {\n\t\t\tisa = PBXFileSystemSynchronizedRootGroup;\n\t\t\tpath = CinePlayer;\n'
  '\t\t\tsourceTree = "<group>";\n\t\t};\n' % SYNC)
w('/* End PBXFileSystemSynchronizedRootGroup section */\n\n')
w('/* Begin PBXFrameworksBuildPhase section */\n')
w(fase(FRAMEWORKS, 'PBXFrameworksBuildPhase', 'Frameworks'))
w('/* End PBXFrameworksBuildPhase section */\n\n')
w('/* Begin PBXGroup section */\n')
w('\t\t%s = {\n\t\t\tisa = PBXGroup;\n\t\t\tchildren = (\n%s\t\t\t);\n\t\t\tsourceTree = "<group>";\n\t\t};\n'
  % (MAIN_GROUP, lijst(['%s /* CinePlayer */' % SYNC, '%s /* Products */' % PRODUCTS])))
w('\t\t%s /* Products */ = {\n\t\t\tisa = PBXGroup;\n\t\t\tchildren = (\n%s\t\t\t);\n\t\t\tname = Products;\n'
  '\t\t\tsourceTree = "<group>";\n\t\t};\n' % (PRODUCTS, lijst(['%s /* CinePlayer.app */' % PRODUCT])))
w('/* End PBXGroup section */\n\n')
w('/* Begin PBXNativeTarget section */\n')
w('\t\t%s /* CinePlayer */ = {\n\t\t\tisa = PBXNativeTarget;\n'
  '\t\t\tbuildConfigurationList = %s /* Build configuration list for PBXNativeTarget "CinePlayer" */;\n'
  '\t\t\tbuildPhases = (\n%s\t\t\t);\n\t\t\tbuildRules = (\n\t\t\t);\n\t\t\tdependencies = (\n\t\t\t);\n'
  '\t\t\tfileSystemSynchronizedGroups = (\n%s\t\t\t);\n\t\t\tname = CinePlayer;\n'
  '\t\t\tpackageProductDependencies = (\n\t\t\t);\n\t\t\tproductName = CinePlayer;\n'
  '\t\t\tproductReference = %s /* CinePlayer.app */;\n\t\t\tproductType = "com.apple.product-type.application";\n\t\t};\n'
  % (TARGET, DOEL_LIST,
     lijst(['%s /* Sources */' % SOURCES, '%s /* Frameworks */' % FRAMEWORKS, '%s /* Resources */' % RESOURCES]),
     lijst(['%s /* CinePlayer */' % SYNC]), PRODUCT))
w('/* End PBXNativeTarget section */\n\n')
w('/* Begin PBXProject section */\n')
w('\t\t%s /* Project object */ = {\n\t\t\tisa = PBXProject;\n\t\t\tattributes = {\n\t\t\t\tBuildIndependentTargetsInParallel = 1;\n'
  '\t\t\t\tLastSwiftUpdateCheck = 1600;\n\t\t\t\tLastUpgradeCheck = 1600;\n\t\t\t\tTargetAttributes = {\n'
  '\t\t\t\t\t%s = {\n\t\t\t\t\t\tCreatedOnToolsVersion = 16.0;\n\t\t\t\t\t};\n\t\t\t\t};\n\t\t\t};\n'
  '\t\t\tbuildConfigurationList = %s /* Build configuration list for PBXProject "CinePlayer" */;\n'
  '\t\t\tdevelopmentRegion = nl;\n\t\t\thasScannedForEncodings = 0;\n\t\t\tknownRegions = (\n\t\t\t\tnl,\n\t\t\t\tBase,\n\t\t\t);\n'
  '\t\t\tmainGroup = %s;\n\t\t\tminimizedProjectReferenceProxies = 1;\n\t\t\tpreferredProjectObjectVersion = 77;\n'
  '\t\t\tproductRefGroup = %s /* Products */;\n\t\t\tprojectDirPath = "";\n\t\t\tprojectRoot = "";\n'
  '\t\t\ttargets = (\n%s\t\t\t);\n\t\t};\n'
  % (PROJECT, TARGET, PROJ_LIST, MAIN_GROUP, PRODUCTS, lijst(['%s /* CinePlayer */' % TARGET])))
w('/* End PBXProject section */\n\n')
w('/* Begin PBXResourcesBuildPhase section */\n')
w(fase(RESOURCES, 'PBXResourcesBuildPhase', 'Resources'))
w('/* End PBXResourcesBuildPhase section */\n\n')
w('/* Begin PBXSourcesBuildPhase section */\n')
w(fase(SOURCES, 'PBXSourcesBuildPhase', 'Sources'))
w('/* End PBXSourcesBuildPhase section */\n\n')
w('/* Begin XCBuildConfiguration section */\n')
w(config(PROJ_DEBUG, 'Debug', GEMEEN + DEBUG))
w(config(PROJ_RELEASE, 'Release', GEMEEN + RELEASE))
w(config(DOEL_DEBUG, 'Debug', DOEL))
w(config(DOEL_RELEASE, 'Release', DOEL))
w('/* End XCBuildConfiguration section */\n\n')
w('/* Begin XCConfigurationList section */\n')
for id_, naam, d, r in ((PROJ_LIST, 'PBXProject "CinePlayer"', PROJ_DEBUG, PROJ_RELEASE),
                        (DOEL_LIST, 'PBXNativeTarget "CinePlayer"', DOEL_DEBUG, DOEL_RELEASE)):
    w('\t\t%s /* Build configuration list for %s */ = {\n\t\t\tisa = XCConfigurationList;\n\t\t\tbuildConfigurations = (\n%s\t\t\t);\n'
      '\t\t\tdefaultConfigurationIsVisible = 0;\n\t\t\tdefaultConfigurationName = Release;\n\t\t};\n'
      % (id_, naam, lijst(['%s /* Debug */' % d, '%s /* Release */' % r])))
w('/* End XCConfigurationList section */\n')
w('\t};\n\trootObject = %s /* Project object */;\n}\n' % PROJECT)

os.makedirs(PROJ, exist_ok=True)
open(os.path.join(PROJ, 'project.pbxproj'), 'w', encoding='utf-8', newline='\n').write(''.join(t))

SCHEMA = os.path.join(PROJ, 'xcshareddata', 'xcschemes', 'CinePlayer.xcscheme')
os.makedirs(os.path.dirname(SCHEMA), exist_ok=True)
ref = ('<BuildableReference\n               BuildableIdentifier = "primary"\n               BlueprintIdentifier = "%s"\n'
       '               BuildableName = "CinePlayer.app"\n               BlueprintName = "CinePlayer"\n'
       '               ReferencedContainer = "container:CinePlayer.xcodeproj">\n            </BuildableReference>' % TARGET)
open(SCHEMA, 'w', encoding='utf-8', newline='\n').write('''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion = "1600" version = "1.7">
   <BuildAction parallelizeBuildables = "YES" buildImplicitDependencies = "YES">
      <BuildActionEntries>
         <BuildActionEntry buildForTesting = "YES" buildForRunning = "YES" buildForProfiling = "YES"
            buildForArchiving = "YES" buildForAnalyzing = "YES">
            %(ref)s
         </BuildActionEntry>
      </BuildActionEntries>
   </BuildAction>
   <LaunchAction buildConfiguration = "Debug" launchStyle = "0" useCustomWorkingDirectory = "NO"
      ignoresPersistentStateOnApp = "NO" debugDocumentVersioning = "YES" allowLocationSimulation = "YES">
      <BuildableProductRunnable runnableDebuggingMode = "0">
         %(ref)s
      </BuildableProductRunnable>
   </LaunchAction>
   <ArchiveAction buildConfiguration = "Release" revealArchiveInOrganizer = "YES">
   </ArchiveAction>
</Scheme>
''' % {'ref': ref})
print('ok')
