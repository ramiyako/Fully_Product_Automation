#!/bin/bash
# Configure Jenkins Allure Plugin

cat << 'EOF'
========================================
Jenkins Allure Plugin Configuration
========================================

The Allure results ARE being generated, but Jenkins doesn't know how to display them.

QUICK FIX - Do these 3 steps in Jenkins UI:
========================================

STEP 1: Install Allure Plugin
------------------------------
1. Go to: http://localhost:8080/manage/pluginManager/available
2. Search for: "Allure"
3. Check the box next to "Allure" plugin
4. Click "Download now and install after restart"
   OR "Install without restart"
5. Wait for installation to complete


STEP 2: Configure Allure Commandline Tool
------------------------------------------
1. Go to: http://localhost:8080/manage/configureTools/
2. Scroll down to "Allure Commandline" section
3. Click "Add Allure Commandline"
4. Name: Allure
5. Check "Install automatically"
6. From "Install from Maven Central" dropdown, select latest version (e.g., 2.27.0)
7. Click "Save"


STEP 3: Verify Job Configuration
---------------------------------
Your Jenkinsfile.integration already has Allure configured!
It has this code:

    allure([
        includeProperties: false,
        jdk: '',
        results: [[path: 'allure-results']],
        reportBuildPolicy: 'ALWAYS'
    ])

So you DON'T need to modify the job!


STEP 4: Run Build Again
------------------------
1. Go to: http://localhost:8080/job/RF-Automation-Integration/
2. Make sure mock equipment is running (bash scripts/start_mock_equipment.sh)
3. Click "Build with Parameters"
4. Click "Build"
5. After build completes, you'll see "Allure Report" link on the left!


========================================
Quick Check: Is Allure Plugin Installed?
========================================

Visit: http://localhost:8080/manage/pluginManager/installed

Search for "allure" - if you see it, it's installed!
If not, follow STEP 1 above.


========================================
Alternative: View Workspace Results
========================================

If you want to see results RIGHT NOW before configuring plugin:

1. Jenkins stores results in workspace:
   /var/lib/jenkins/workspace/RF-Automation-Integration/allure-results/

2. Generate report manually:
   sudo allure generate /var/lib/jenkins/workspace/RF-Automation-Integration/allure-results -o /tmp/allure-report
   allure open /tmp/allure-report

3. Or copy results to your local directory:
   sudo cp -r /var/lib/jenkins/workspace/RF-Automation-Integration/allure-results/* ./allure-results/
   sudo chown -R $USER:$USER ./allure-results/
   allure generate allure-results --clean -o allure-report
   allure open allure-report


========================================
MOST IMPORTANT: The 2-Minute Fix
========================================

1. Open: http://localhost:8080/manage/pluginManager/available
2. Search: "Allure"
3. Install the plugin
4. Go to: http://localhost:8080/manage/configureTools/
5. Add Allure Commandline (name: "Allure", install automatically)
6. Run build again
7. Click "Allure Report" link in build!

THAT'S IT!

EOF
