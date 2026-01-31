// Mobile File Manager - Interactive Functionality

// Get DOM elements
const backdrop = document.getElementById('backdrop');
const bottomSheet = document.getElementById('bottom-sheet');
const sheetFileName = document.getElementById('sheet-file-name');
const sheetFileMeta = document.getElementById('sheet-file-meta');
const fileItems = document.querySelectorAll('.file-item');
const fileMoreButtons = document.querySelectorAll('.file-more');

// Current selected file
let currentFile = null;

// Open bottom sheet
function openBottomSheet(fileName, fileMeta, fileType) {
    currentFile = { fileName, fileMeta, fileType };
    sheetFileName.textContent = fileName;
    sheetFileMeta.textContent = fileMeta;
    
    backdrop.classList.add('active');
    bottomSheet.classList.add('active');
    document.body.style.overflow = 'hidden';
}

// Close bottom sheet
function closeBottomSheet() {
    backdrop.classList.remove('active');
    bottomSheet.classList.remove('active');
    document.body.style.overflow = '';
    currentFile = null;
}

// Handle file item clicks (tap on main area)
fileItems.forEach(item => {
    const mainArea = item.cloneNode(true);
    
    item.addEventListener('click', (e) => {
        // Ignore if clicking the more button
        if (e.target.closest('.file-more')) {
            return;
        }
        
        const fileName = item.dataset.name;
        const fileType = item.dataset.type;
        const metaText = item.querySelector('.file-meta').textContent;
        
        // For folders, would navigate into folder
        // For files, would open preview
        if (fileType === 'folder') {
            console.log('Navigate to folder:', fileName);
            // Add folder navigation animation
            item.style.transform = 'scale(0.95)';
            setTimeout(() => {
                item.style.transform = '';
            }, 150);
        } else {
            console.log('Open file preview:', fileName);
        }
    });
});

// Handle more button clicks
fileMoreButtons.forEach((btn, index) => {
    btn.addEventListener('click', (e) => {
        e.stopPropagation();
        
        const item = btn.closest('.file-item');
        const fileName = item.dataset.name;
        const fileType = item.dataset.type;
        const metaText = item.querySelector('.file-meta').textContent;
        
        openBottomSheet(fileName, metaText, fileType);
    });
});

// Close bottom sheet when clicking backdrop
backdrop.addEventListener('click', closeBottomSheet);

// Handle swipe down to close
let touchStartY = 0;
let touchEndY = 0;

bottomSheet.addEventListener('touchstart', (e) => {
    touchStartY = e.touches[0].clientY;
}, { passive: true });

bottomSheet.addEventListener('touchmove', (e) => {
    touchEndY = e.touches[0].clientY;
    const diff = touchEndY - touchStartY;
    
    // Only allow dragging down
    if (diff > 0) {
        bottomSheet.style.transform = `translateY(${diff}px)`;
    }
}, { passive: true });

bottomSheet.addEventListener('touchend', () => {
    const diff = touchEndY - touchStartY;
    
    // If dragged down more than 100px, close the sheet
    if (diff > 100) {
        closeBottomSheet();
    }
    
    // Reset transform
    bottomSheet.style.transform = '';
    touchStartY = 0;
    touchEndY = 0;
});

// Action handlers
const actionButtons = {
    open: document.getElementById('action-open'),
    share: document.getElementById('action-share'),
    download: document.getElementById('action-download'),
    rename: document.getElementById('action-rename'),
    move: document.getElementById('action-move'),
    info: document.getElementById('action-info'),
    delete: document.getElementById('action-delete')
};

// Open action
actionButtons.open.addEventListener('click', () => {
    console.log('Opening:', currentFile.fileName);
    closeBottomSheet();
    // Add haptic feedback simulation
    if (navigator.vibrate) {
        navigator.vibrate(10);
    }
});

// Share action
actionButtons.share.addEventListener('click', () => {
    console.log('Sharing:', currentFile.fileName);
    
    // Web Share API if available
    if (navigator.share) {
        navigator.share({
            title: currentFile.fileName,
            text: `Check out this file: ${currentFile.fileName}`,
        }).then(() => {
            console.log('Shared successfully');
            closeBottomSheet();
        }).catch(err => {
            console.log('Share failed:', err);
        });
    } else {
        alert('Share: ' + currentFile.fileName);
        closeBottomSheet();
    }
});

// Download action
actionButtons.download.addEventListener('click', () => {
    console.log('Downloading:', currentFile.fileName);
    
    // Simulate download
    const notification = document.createElement('div');
    notification.textContent = `Downloading ${currentFile.fileName}...`;
    notification.style.cssText = `
        position: fixed;
        bottom: 24px;
        left: 50%;
        transform: translateX(-50%);
        background: var(--bg-elevated);
        color: var(--text-primary);
        padding: 12px 20px;
        border-radius: 8px;
        font-size: 14px;
        z-index: 1000;
        box-shadow: 0 4px 12px rgba(0, 0, 0, 0.4);
    `;
    document.body.appendChild(notification);
    
    setTimeout(() => {
        notification.remove();
    }, 2000);
    
    closeBottomSheet();
});

// Rename action
actionButtons.rename.addEventListener('click', () => {
    console.log('Renaming:', currentFile.fileName);
    
    const newName = prompt('Enter new name:', currentFile.fileName);
    if (newName && newName !== currentFile.fileName) {
        console.log('Renamed to:', newName);
        // Update UI would happen here
    }
    
    closeBottomSheet();
});

// Move action
actionButtons.move.addEventListener('click', () => {
    console.log('Moving:', currentFile.fileName);
    alert('Move to folder feature would open here');
    closeBottomSheet();
});

// Info action
actionButtons.info.addEventListener('click', () => {
    console.log('Showing info for:', currentFile.fileName);
    alert(`File Details:\n\nName: ${currentFile.fileName}\n${currentFile.fileMeta}\nType: ${currentFile.fileType}`);
    closeBottomSheet();
});

// Delete action
actionButtons.delete.addEventListener('click', () => {
    console.log('Deleting:', currentFile.fileName);
    
    const confirmed = confirm(`Delete "${currentFile.fileName}"?\n\nThis action cannot be undone.`);
    if (confirmed) {
        console.log('Deleted:', currentFile.fileName);
        
        // Vibration feedback for destructive action
        if (navigator.vibrate) {
            navigator.vibrate([10, 50, 10]);
        }
        
        // Would remove from UI here
    }
    
    closeBottomSheet();
});

// Search button handler
const searchBtn = document.getElementById('search-btn');
searchBtn.addEventListener('click', () => {
    console.log('Opening search');
    alert('Search interface would open here');
});

// Menu button handler
const menuBtn = document.getElementById('menu-btn');
menuBtn.addEventListener('click', () => {
    console.log('Opening menu');
    alert('Navigation menu would open here');
});

// Prevent body scroll when bottom sheet is open
document.addEventListener('touchmove', (e) => {
    if (bottomSheet.classList.contains('active') && !bottomSheet.contains(e.target)) {
        e.preventDefault();
    }
}, { passive: false });

// Keyboard support - ESC to close bottom sheet
document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape' && bottomSheet.classList.contains('active')) {
        closeBottomSheet();
    }
});

// Add subtle scroll shadow to indicate more content
const sheetContent = document.querySelector('.bottom-sheet-content');
let scrollTimeout;

sheetContent.addEventListener('scroll', () => {
    clearTimeout(scrollTimeout);
    sheetContent.style.borderTop = '1px solid var(--border-color)';
    
    scrollTimeout = setTimeout(() => {
        if (sheetContent.scrollTop === 0) {
            sheetContent.style.borderTop = 'none';
        }
    }, 150);
});

console.log('Mobile File Manager initialized');
console.log('Features: Bottom sheets, swipe gestures, haptic feedback');
