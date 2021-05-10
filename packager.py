import re
import zipfile
import os
import click

# ---------------------------------------------------------------------------------------------------
# -- Constants
# ---------------------------------------------------------------------------------------------------

SOURCE_DIR = "TidyPlates_ThreatPlates"

TOC_FILE = "TidyPlates_ThreatPlates.toc"
LIBS_XML_FILE = "Libs\\Libs.xml"

TEMPLATE_TOC_FILE = "Template_" + TOC_FILE
TEMPLATE_LIBS_XML_FILE = os.path.split(LIBS_XML_FILE)[0] + "\\Template_" + os.path.split(LIBS_XML_FILE)[1]

IGNORE_DIR = [".git", ".idea", "Source", "Test"]
IGNORE_FILE = [".gitignore", "README.md", "packager.py", "TidyPlates_ThreatPlates.iml", "UsedColors", "exclude.lst",
               # Ignore this files because they are replaced with Classic/Mainline specific versions:
               TOC_FILE, TEMPLATE_TOC_FILE, ".\\" + LIBS_XML_FILE, ".\\" + TEMPLATE_LIBS_XML_FILE]
IGNORE_EXT = [".bat", ".txt", ".db", ".zip",
              ".bmp", ".gif", ".jpg", ".png", ".psd", "*.tif", ".xcf"]

EXCLUDE_TAGS_BY_VERSION = {
    "Classic":    { "tbc-classic", "mainline" },
    "TBC-Classic": { "classic", "mainline" },
    "Mainline":     { "classic", "tbc-classic" },
}

# ---------------------------------------------------------------------------------------------------
# -- Zipping Functions
# ---------------------------------------------------------------------------------------------------
# Code from:
# https://stackoverflow.com/questions/31779392/exclude-a-directory-from-getting-zipped-using-zipfile-module-in-python
def zip_dir_is_path_valid(path, ignore_dir, ignore_file, ignore_ext):
    splited = None

    if os.path.isfile(path):
        if ignore_file:
            if path in ignore_file:
                return False

        if ignore_ext:
            _, ext = os.path.splitext(path)
            if ext in ignore_ext:
                return False

        splited = os.path.dirname(path).split('\\/')
    else:
        if not ignore_dir:
            return True
        splited = path.split('\\/')

    for s in splited:
        if s in ignore_dir:  # You can also use set.intersection or [x for],
            return False

    return True


def zip_dir_helper(path, root_dir, zf, ignore_dir=[], ignore_file=[], ignore_ext=[]):
    # zf is zipfile handle
    if os.path.isfile(path):
        if zip_dir_is_path_valid(path, ignore_dir, ignore_file, ignore_ext):
            relative = os.path.relpath(path, root_dir)
            zf.write(path, SOURCE_DIR + "\\" + relative)
        return

    ls = os.listdir(path)
    for subFileOrDir in ls:
        if not zip_dir_is_path_valid(subFileOrDir, ignore_dir, ignore_file, ignore_ext):
            continue

        joinedPath = os.path.join(path, subFileOrDir)
        zip_dir_helper(joinedPath, root_dir, zf, ignore_dir, ignore_file, ignore_ext)


def zip_dir(path, zf, ignore_dir=[], ignore_file=[], ignore_ext=[]):
    root_dir = path if os.path.isdir(path) else os.path.dirname(path)
    zip_dir_helper(path, root_dir, zf, ignore_dir, ignore_file, ignore_ext)
    pass


# ---------------------------------------------------------------------------------------------------
# -- Packaging Functions
# ---------------------------------------------------------------------------------------------------

def create_toc_file(wow_version):
    with open(TEMPLATE_TOC_FILE, encoding="utf-8-sig") as f:
        toc_file_content = f.readlines()

    # Get version from TOC file
    for line in toc_file_content:
        m = re.match("## Version: (.*)", line)
        if m:
            version_no = m.group(1)

    toc_file_content = "".join(toc_file_content)

    # Remove parts that don't belong to the version that is packaged from TOC file
    version_tag = wow_version.lower()
    print (version_tag)
    exclude_tags = EXCLUDE_TAGS_BY_VERSION[wow_version]

    toc_file_content = re.sub(r"#@" + version_tag + "@[^\n]*\n", "", toc_file_content)
    toc_file_content = re.sub(r"#@end-" + version_tag + "@[^\n]*\n", "", toc_file_content)
    for exclude_tag in exclude_tags:
        toc_file_content = re.sub(r"#@" + exclude_tag + "@\n[^@]*#@end-" + exclude_tag + "@\n", "", toc_file_content)
        # Replace @VERSION@ parameter in TOC file
        # toc_file_content = re.sub(r"@VERSION@", args.version, toc_file_content)

    return toc_file_content, version_no


def create_libs_xml_file(wow_version):
    # Parse Libs.xml to get packages that are only used for Classic
    with open(TEMPLATE_LIBS_XML_FILE, encoding="utf-8-sig") as f:
        libs_file_content = f.readlines()
    libs_file_content = "".join(libs_file_content)

    version_tag = wow_version.lower()
    exclude_tags = EXCLUDE_TAGS_BY_VERSION[wow_version]

    # Remove parts that don't belong to the version that is packaged from TOC file
    libs_file_content = re.sub(r"@" + version_tag + "@", "-->", libs_file_content)
    libs_file_content = re.sub(r"@end-" + version_tag + "@", "<!--", libs_file_content)

    for exclude_tag in exclude_tags:
        ignore_lib_dirs = []
        m = re.search("@" + exclude_tag + "@([^@]*)@end-" + exclude_tag + "@", libs_file_content, re.MULTILINE)
        if m:
            for line in m.group(1).split("\n"):
                m_lib = re.match("\s*<(Include|Script) file=\"(.*)\"/>", line)
                if m_lib:
                    lib_dir = os.path.dirname(m_lib.group(2))
                    ignore_lib_dirs.append(lib_dir)
        libs_file_content = re.sub(r"@" + exclude_tag + "@\n[^@]*@end-" + exclude_tag + "@", "", libs_file_content)

    return libs_file_content, ignore_lib_dirs


# ZIP package for WoW version
def create_package(wow_version, package_dir):
    #packager_path = os.path.dirname(os.path.realpath(__file__))

    toc_file_content, version_no = create_toc_file(wow_version)
    libs_file_content, ignore_lib_dirs = create_libs_xml_file(wow_version)

    # ---------------------------------------------------------------------------------------------------
    # -- Zip Packages
    # ---------------------------------------------------------------------------------------------------
    package_name = "ThreatPlates"
    if wow_version == "Classic" or wow_version == "TBC-Classic":
        package_name += "-" + wow_version

    package_file_name = package_dir + "\\" + package_name + "-" + version_no + ".zip"

    package_file = zipfile.ZipFile(package_file_name, "w", compression=zipfile.ZIP_DEFLATED, allowZip64=True, compresslevel=9)
    zip_dir(".", package_file, ignore_dir=IGNORE_DIR+ignore_lib_dirs, ignore_file=IGNORE_FILE, ignore_ext=IGNORE_EXT)

    # Add TOC file to package
    package_file.writestr(SOURCE_DIR + "\\" + TOC_FILE, toc_file_content)
    # Add Libs.xml file to package
    package_file.writestr(SOURCE_DIR + "\\" + LIBS_XML_FILE, libs_file_content)

    print("=> Created package file " + package_file_name)

    package_file.close()

# ---------------------------------------------------------------------------------------------------
# -- ...
# ---------------------------------------------------------------------------------------------------


def get_wow_version():
    working_dir = os.getcwd()
    if "_retail_" in working_dir:
        return "Mainline"
    elif "_classic_beta_" in working_dir:
        return "TBC-Classic"
    elif "_classic_" in working_dir:
        return "Classic"
    elif "_ptr_" in working_dir:
        return "Mainline"
    elif "_beta_" in working_dir:
        return "Mainline"
    else:
        print("Unknown working directory. Exiting ...")
        exit(-1)


def template_is_out_of_date(file, template_file):
    if not os.path.exists(file):
        return True
    else:
        last_modified_file = os.path.getmtime(file)
        last_modified_template_file = os.path.getmtime(template_file)

        return last_modified_file <= last_modified_template_file


def write_to_file(file, content):
    with open(file, 'w') as f:
        f.write(content)
        f.close()

# ---------------------------------------------------------------------------------------------------
# -- Argument Parser
# ---------------------------------------------------------------------------------------------------

@click.command()
@click.option('--package-dir', type=str, help='Create release versions of Threat Plates in the specified directory.')
def packager_main(package_dir):
    """Create a package for a new release of Threat Plates for Mainline and Classic and TBC Classic WoW."""
    wow_version = get_wow_version()
    print("WoW version:", wow_version)

    # If TOC file is out of date or does not exists, create it:
    if template_is_out_of_date(TOC_FILE, TEMPLATE_TOC_FILE):
        print("TOC file is outdated ... updating it!")
        file_content, version_no = create_toc_file(wow_version)
        write_to_file(TOC_FILE, file_content)

    # If TOC file is out of date or does not exists, create it:
    if template_is_out_of_date(LIBS_XML_FILE, TEMPLATE_LIBS_XML_FILE):
        print("Libs.xml file is outdated ... updating it!")
        file_content, version_no = create_libs_xml_file(wow_version)
        write_to_file(LIBS_XML_FILE, file_content)

    # ---------------------------------------------------------------------------------------------------
    # -- Create packages for Mainline and Classic
    # ---------------------------------------------------------------------------------------------------
    if package_dir:
        create_package("Mainline", package_dir)
        create_package("Classic", package_dir)
        create_package("TBC-Classic", package_dir)

if __name__ == '__main__':
    packager_main()
