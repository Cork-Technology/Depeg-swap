const fs = require("fs");
const path = require("path");

// Directory where the contracts are located
const contractsDir = path.join(__dirname, "../../artifacts/contracts");

// Function to organise JSON artifacts files
function organiseABIFiles(directory) {
  const files = fs.readdirSync(directory);

  files.forEach((file) => {
    const fullPath = path.join(directory, file);

    // Check if the file is a directory, recurse into it
    if (fs.statSync(fullPath).isDirectory()) {
      organiseABIFiles(fullPath); // Recursively process subdirectories
    } else if (file.endsWith(".json") && !file.endsWith(".dbg.json")) {
      // Move only non-dbg .json files
      const destPath = path.join(contractsDir, file);
      fs.renameSync(fullPath, destPath);
      console.log(`Moved: ${file} to ${destPath}`);
    } else {
      // Delete unwanted files that are not .json (including .ts, .dbg.json etc)
      fs.unlinkSync(fullPath);
      console.log(`Deleted: ${file}`);
    }
  });
}

function deleteEmptyDirectories(directory) {
    const files = fs.readdirSync(directory);

    // Recursively check for directories
    files.forEach(file => {
        const fullPath = path.join(directory, file);

        if (fs.statSync(fullPath).isDirectory()) {
            deleteEmptyDirectories(fullPath); // Recursively process subdirectories

            // After processing, remove the folder if it's empty
            if (fs.readdirSync(fullPath).length === 0) {
                fs.rmdirSync(fullPath);
                console.log(`Deleted empty directory: ${fullPath}`);
            }
        }
    });
}

// Run the script starting from the top-level contracts directory
organiseABIFiles(contractsDir);
deleteEmptyDirectories(contractsDir); // Clean up empty directories

console.log("Files organised successfully.");
