# Quick Jenkins Job Setup - 2 Minutes

## Step 1: Open Jenkins
Open in Chrome: **http://localhost:8080**

## Step 2: Create New Job
1. Click **"New Item"** (top left)
2. Enter name: **RF-Automation-Integration**
3. Select: **Pipeline**
4. Click **OK**

## Step 3: Configure Pipeline Source
Scroll down to **"Pipeline"** section at the bottom:

- **Definition**: Select "Pipeline script from SCM"
- **SCM**: Select "Git"
- **Repository URL**: Paste this path:
  ```
  /home/ramiy@D-fend.local/py_projects/Fully_Product_Automation
  ```
- **Branch Specifier**: `*/integration`
- **Script Path**: `Jenkinsfile.integration`

## Step 4: Save
Click **Save** at the bottom

## Step 5: First Build
1. Click **"Build Now"** in the left menu
2. The first build will run and automatically create all parameters
3. After the first build, you'll see **"Build with Parameters"** option

## Done!
From the second build onwards, you can click **"Build with Parameters"** to select:
- Test Suite
- RF Physics settings
- Noise floor
- And more!

---

**That's it!** The Jenkinsfile already has all parameters defined. They'll appear after the first build.
