class CarPlayController {
  constructor() {
    this.isPlaying = false
    this.currentSong = null
    this.progress = 0
    this.duration = 180 // Default 3 minutes
    this.volume = 50
    this.range = 15
    this.queue = {
      songs: [],
      currentIndex: 0,
      shuffle: false,
      repeat_mode: "none",
    }

    this.initializeElements()
    this.bindEvents()
    this.updateTime()
    this.startTimeUpdate()
  }

  initializeElements() {
    // Control elements
    this.playPauseBtn = document.getElementById("playPauseBtn")
    this.previousBtn = document.getElementById("previousBtn")
    this.nextBtn = document.getElementById("nextBtn")
    this.closeBtn = document.getElementById("closeBtn")

    // Display elements
    this.trackTitle = document.getElementById("trackTitle")
    this.trackArtist = document.getElementById("trackArtist")
    this.trackStatus = document.getElementById("trackStatus")
    this.albumArt = document.getElementById("albumArt")
    this.currentTimeDisplay = document.getElementById("currentTimeDisplay")
    this.totalTimeDisplay = document.getElementById("totalTimeDisplay")

    // Progress elements
    this.progressBar = document.getElementById("progressBar")
    this.progressFill = document.getElementById("progressFill")
    this.progressHandle = document.getElementById("progressHandle")

    // Input elements
    this.quickUrlInput = document.getElementById("quickUrlInput")
    this.quickPlayBtn = document.getElementById("quickPlayBtn")
    this.settingsBtn = document.getElementById("settingsBtn")

    // Main control elements
    this.volumeSlider = document.getElementById("volumeSlider")
    this.volumeValue = document.getElementById("volumeValue")

    // Modal elements
    this.settingsModal = document.getElementById("settingsModal")
    this.modalCloseBtn = document.getElementById("modalCloseBtn")
    this.urlInput = document.getElementById("urlInput")
    this.rangeSlider = document.getElementById("rangeSlider")
    this.rangeValue = document.getElementById("rangeValue")
    this.playBtn = document.getElementById("playBtn")
    this.addToQueueBtn = document.getElementById("addToQueueBtn")

    // Queue elements
    this.queueList = document.getElementById("queueList")
    this.queueCount = document.getElementById("queueCount")
    this.clearQueueBtn = document.getElementById("clearQueueBtn")
    this.shuffleBtn = document.getElementById("shuffleBtn")
    this.repeatBtn = document.getElementById("repeatBtn")

    // Icons
    this.playIcon = document.getElementById("playIcon")
    this.pauseIcon = document.getElementById("pauseIcon")

    // Time display
    this.currentTime = document.getElementById("currentTime")
  }

  bindEvents() {
    // Playback controls
    this.playPauseBtn.addEventListener("click", () => this.togglePlayPause())
    this.previousBtn.addEventListener("click", () => this.previousTrack())
    this.nextBtn.addEventListener("click", () => this.nextTrack())
    this.closeBtn.addEventListener("click", () => this.close())

    // Quick controls
    this.quickPlayBtn.addEventListener("click", () => this.quickPlay())
    this.settingsBtn.addEventListener("click", () => this.openSettings())

    // Main controls
    this.volumeSlider.addEventListener("input", (e) => {
      this.volume = Number.parseInt(e.target.value)
      this.volumeValue.textContent = this.volume
      this.fetch("setVolume", { volume: this.volume }) // Live update volume
    })

    // Modal controls
    this.modalCloseBtn.addEventListener("click", () => this.closeSettings())
    this.playBtn.addEventListener("click", () => this.playMusic())
    this.addToQueueBtn.addEventListener("click", () => this.addToQueue())

    // Range slider
    this.rangeSlider.addEventListener("input", (e) => {
      this.range = Number.parseInt(e.target.value)
      this.rangeValue.textContent = this.range
    })

    // Queue controls
    if (this.clearQueueBtn) {
      this.clearQueueBtn.addEventListener("click", () => this.clearQueue())
    }
    if (this.shuffleBtn) {
      this.shuffleBtn.addEventListener("click", () => this.toggleShuffle())
    }
    if (this.repeatBtn) {
      this.repeatBtn.addEventListener("click", () => this.cycleRepeatMode())
    }

    // Progress bar
    this.progressBar.addEventListener("click", (e) => this.seekTo(e))

    // Keyboard shortcuts
    document.addEventListener("keydown", (e) => this.handleKeyboard(e))

    // URL input enter key
    this.quickUrlInput.addEventListener("keypress", (e) => {
      if (e.key === "Enter") {
        this.quickPlay()
      }
    })

    this.urlInput.addEventListener("keypress", (e) => {
      if (e.key === "Enter") {
        this.smartPlay()
      }
    })

    // Modal overlay click
    this.settingsModal.addEventListener("click", (e) => {
      if (e.target === this.settingsModal) {
        this.closeSettings()
      }
    })
  }

  handleKeyboard(e) {
    switch (e.key) {
      case "Escape":
        if (this.settingsModal.classList.contains("active")) {
          this.closeSettings()
        } else {
          this.close()
        }
        break
      case " ":
        e.preventDefault()
        this.togglePlayPause()
        break
      case "Enter":
        if (!this.settingsModal.classList.contains("active")) {
          this.openSettings()
        }
        break
      case "ArrowRight":
        e.preventDefault()
        this.nextTrack()
        break
      case "ArrowLeft":
        e.preventDefault()
        this.previousTrack()
        break
    }
  }

  togglePlayPause() {
    if (this.isPlaying) {
      this.pauseMusic()
    } else {
      if (this.currentSong) {
        this.resumeMusic()
      } else {
        this.openSettings()
      }
    }
  }

  quickPlay() {
    const url = this.quickUrlInput.value.trim()
    if (!url) {
      this.showError("Please enter a YouTube URL")
      return
    }

    // Smart play logic: if music is playing, add to queue, otherwise play now
    const playNow = !this.isPlaying
    this.playMusicWithUrl(url, playNow)
    this.quickUrlInput.value = ""

    if (!playNow) {
      this.showNotification("Added to queue")
    }
  }

  smartPlay() {
    const url = this.urlInput.value.trim()
    if (!url) {
      this.showError("Please enter a YouTube URL")
      return
    }

    // Smart play logic: if music is playing, add to queue, otherwise play now
    const playNow = !this.isPlaying
    this.playMusicWithUrl(url, playNow)
    this.urlInput.value = ""
    this.closeSettings()

    if (!playNow) {
      this.showNotification("Added to queue")
    }
  }

  playMusic() {
    const url = this.urlInput.value.trim()
    if (!url) {
      this.showError("Please enter a YouTube URL")
      return
    }

    this.playMusicWithUrl(url, true) // Always play immediately from modal
    this.urlInput.value = ""
    this.closeSettings()
  }

  addToQueue() {
    const url = this.urlInput.value.trim()
    if (!url) {
      this.showError("Please enter a YouTube URL")
      return
    }

    this.playMusicWithUrl(url, false) // Always add to queue
    this.urlInput.value = ""
    this.closeSettings()
  }

  playMusicWithUrl(url, playNow = true) {
    // Show loading state if playing now
    if (playNow) {
      this.trackTitle.textContent = "Loading..."
      this.trackArtist.textContent = "Preparing audio stream..."
      this.trackStatus.textContent = "Connecting to YouTube..."
    }

    const endpoint = playNow ? "playMusic" : "addToQueue"

    this.fetch(endpoint, {
      url: url,
      volume: this.volume,
      range: this.range,
      loop: false, // Loop is handled by repeat mode, not individual song loop
      playNow: playNow,
    })
      .then((response) => {
        if (response.success) {
          console.log(`${endpoint} request sent successfully`)
          if (!playNow) {
            this.showNotification("Added to queue")
          }
        } else {
          this.showError(response.error || `Failed to ${playNow ? "play music" : "add to queue"}`)
          // Reset loading state on error
          if (playNow) {
            this.trackTitle.textContent = "No Music Playing"
            this.trackArtist.textContent = "Select a song to begin"
            this.trackStatus.textContent = ""
          }
        }
      })
      .catch((error) => {
        console.error(`Error ${playNow ? "playing music" : "adding to queue"}:`, error)
        this.showError("Failed to communicate with game")
        // Reset loading state on error
        if (playNow) {
          this.trackTitle.textContent = "No Music Playing"
          this.trackArtist.textContent = "Select a song to begin"
          this.trackStatus.textContent = ""
        }
      })
  }

  // The stopMusic function is still here but not tied to a button.
  // It can be called by other logic if a full sound destruction is needed.
  stopMusic() {
    this.fetch("stopMusic", {})
      .then((response) => {
        if (response.success) {
          console.log("Music stop request sent successfully")
        } else {
          this.showError(response.error || "Failed to stop music")
        }
      })
      .catch((error) => {
        console.error("Error stopping music:", error)
        this.showError("Failed to communicate with game")
      })
  }

  pauseMusic() {
    this.fetch("pauseMusic", {})
      .then((response) => {
        if (response.success) {
          console.log("Music paused successfully")
        } else {
          this.showError(response.error || "Failed to pause music")
        }
      })
      .catch((error) => {
        console.error("Error pausing music:", error)
        this.showError("Failed to communicate with game")
      })
  }

  resumeMusic() {
    this.fetch("resumeMusic", {})
      .then((response) => {
        if (response.success) {
          console.log("Music resumed successfully")
        } else {
          this.showError(response.error || "Failed to resume music")
        }
      })
      .catch((error) => {
        console.error("Error resuming music:", error)
        this.showError("Failed to communicate with game")
      })
  }

  previousTrack() {
    // For now, just stop current music
    // You could implement previous song logic here
    this.stopMusic()
  }

  nextTrack() {
    this.fetch("playNext", {})
      .then((response) => {
        if (response.success) {
          console.log("Playing next song")
        } else {
          this.showError(response.error || "No next song available")
        }
      })
      .catch((error) => {
        console.error("Error playing next song:", error)
        this.showError("Failed to communicate with game")
      })
  }

  clearQueue() {
    this.fetch("clearQueue", {})
      .then((response) => {
        if (response.success) {
          console.log("Queue cleared")
          this.showNotification("Queue cleared")
        } else {
          this.showError(response.error || "Failed to clear queue")
        }
      })
      .catch((error) => {
        console.error("Error clearing queue:", error)
        this.showError("Failed to communicate with game")
      })
  }

  toggleShuffle() {
    this.fetch("toggleShuffle", {})
      .then((response) => {
        if (response.success) {
          console.log("Shuffle toggled")
        } else {
          this.showError(response.error || "Failed to toggle shuffle")
        }
      })
      .catch((error) => {
        console.error("Error toggling shuffle:", error)
        this.showError("Failed to communicate with game")
      })
  }

  cycleRepeatMode() {
    const modes = ["none", "one", "all"]
    const currentIndex = modes.indexOf(this.queue.repeat_mode)
    const nextMode = modes[(currentIndex + 1) % modes.length]

    this.fetch("setRepeatMode", { mode: nextMode })
      .then((response) => {
        if (response.success) {
          console.log(`Repeat mode set to: ${nextMode}`)
        } else {
          this.showError(response.error || "Failed to set repeat mode")
        }
      })
      .catch((error) => {
        console.error("Error setting repeat mode:", error)
        this.showError("Failed to communicate with game")
      })
  }

  removeFromQueue(index) {
    this.fetch("removeFromQueue", { index: index })
      .then((response) => {
        if (response.success) {
          console.log(`Removed song ${index} from queue`)
        } else {
          this.showError(response.error || "Failed to remove from queue")
        }
      })
      .catch((error) => {
        console.error("Error removing from queue:", error)
        this.showError("Failed to communicate with game")
      })
  }

  updateQueueDisplay() {
    if (!this.queueList) return

    this.queueList.innerHTML = ""

    // Update queue count
    if (this.queueCount) {
      const count = this.queue.songs.length
      this.queueCount.textContent = `${count} song${count !== 1 ? "s" : ""}`
    }

    if (this.queue.songs.length === 0) {
      const emptyItem = document.createElement("div")
      emptyItem.className = "queue-item empty"
      emptyItem.innerHTML = `
        <span>No songs in queue</span>
      `
      this.queueList.appendChild(emptyItem)
      return
    }

    this.queue.songs.forEach((song, index) => {
      const queueItem = document.createElement("div")
      queueItem.className = `queue-item ${index + 1 === this.queue.currentIndex ? "current" : ""}`

      queueItem.innerHTML = `
        <div class="queue-song-info">
          <div class="queue-song-title">${this.truncateText(song.title, 25)}</div>
          <div class="queue-song-artist">${this.truncateText(song.artist, 30)}</div>
        </div>
        <div class="queue-controls">
          <button class="queue-remove-btn" onclick="window.carplay.removeFromQueue(${index + 1})">×</button>
        </div>
      `

      this.queueList.appendChild(queueItem)
    })
  }

  truncateText(text, maxLength) {
    if (text.length <= maxLength) return text
    return text.substring(0, maxLength - 3) + "..."
  }

  updateScrollingText(element, text) {
    element.textContent = text

    // Remove existing scroll class
    element.classList.remove("scroll")

    // Check if text overflows
    setTimeout(() => {
      const containerWidth = element.parentElement.offsetWidth
      const textWidth = element.scrollWidth

      if (textWidth > containerWidth) {
        element.classList.add("scroll")
      }
    }, 100)
  }

  updateShuffleButton() {
    if (!this.shuffleBtn) return

    if (this.queue.shuffle) {
      this.shuffleBtn.classList.add("active")
      this.shuffleBtn.title = "Shuffle: On"
    } else {
      this.shuffleBtn.classList.remove("active")
      this.shuffleBtn.title = "Shuffle: Off"
    }
  }

  updateRepeatButton() {
    if (!this.repeatBtn) return

    this.repeatBtn.classList.remove("repeat-none", "repeat-one", "repeat-all")
    this.repeatBtn.classList.add(`repeat-${this.queue.repeat_mode}`)

    const titles = {
      none: "Repeat: Off",
      one: "Repeat: One",
      all: "Repeat: All",
    }
    this.repeatBtn.title = titles[this.queue.repeat_mode] || "Repeat: Off"
  }

  seekTo(e) {
    if (!this.currentSong) return

    const rect = this.progressBar.getBoundingClientRect()
    const clickX = e.clientX - rect.left
    const percentage = clickX / rect.width

    const seekTime = Math.max(0, Math.min(percentage * this.duration, this.duration))

    this.fetch("seekMusic", { time: seekTime })
      .then((response) => {
        if (response.success) {
          this.progress = seekTime
          this.updateProgressDisplay()
        }
      })
      .catch((error) => {
        console.error("Error seeking music:", error)
      })
  }

  openSettings() {
    this.settingsModal.classList.add("active")
    this.urlInput.focus()
  }

  closeSettings() {
    this.settingsModal.classList.remove("active")
  }

  close() {
    this.fetch("close", {})
      .then(() => {
        console.log("CarPlay closed")
      })
      .catch((error) => {
        console.error("Error closing CarPlay:", error)
      })
  }

  showError(message) {
    this.showToast(message, "error")
  }

  showNotification(message) {
    this.showToast(message, "success")
  }

  showToast(message, type = "info") {
    // Create a simple toast notification
    const toast = document.createElement("div")
    toast.className = `toast toast-${type}`
    toast.textContent = message

    const colors = {
      error: "#ff3b30",
      success: "#34c759",
      info: "#007aff",
    }

    toast.style.cssText = `
      position: fixed;
      top: 40px;
      right: 40px;
      background: ${colors[type] || colors.info};
      color: white;
      padding: 18px 30px;
      border-radius: 15px;
      font-weight: 600;
      font-size: 16px;
      z-index: 2000;
      animation: slideIn 0.3s ease;
      box-shadow: 0 10px 30px rgba(0, 0, 0, 0.4);
    `

    document.body.appendChild(toast)

    setTimeout(() => {
      toast.style.animation = "slideOut 0.3s ease"
      setTimeout(() => {
        if (document.body.contains(toast)) {
          document.body.removeChild(toast)
        }
      }, 300)
    }, 4000)
  }

  updatePlayPauseButton() {
    if (this.isPlaying) {
      this.playIcon.style.display = "none"
      this.pauseIcon.style.display = "block"
    } else {
      this.playIcon.style.display = "block"
      this.pauseIcon.style.display = "none"
    }
  }

  updateProgressDisplay() {
    const percentage = (this.progress / this.duration) * 100
    this.progressFill.style.width = `${percentage}%`
    this.progressHandle.style.left = `${percentage}%`

    this.currentTimeDisplay.textContent = this.formatTime(this.progress)
    this.totalTimeDisplay.textContent = this.formatTime(this.duration)
  }

  formatTime(seconds) {
    const mins = Math.floor(seconds / 60)
    const secs = Math.floor(seconds % 60)
    return `${mins}:${secs.toString().padStart(2, "0")}`
  }

  updateTime() {
    const now = new Date()
    const hours = now.getHours().toString().padStart(2, "0")
    const minutes = now.getMinutes().toString().padStart(2, "0")
    this.currentTime.textContent = `${hours}:${minutes}`
  }

  startTimeUpdate() {
    this.updateTime()
    setInterval(() => this.updateTime(), 60000) // Update every minute
  }

  // NUI Communication
  async fetch(endpoint, data) {
    try {
      const resourceName = window.GetParentResourceName ? window.GetParentResourceName() : "modern-carplay"
      const response = await fetch(`https://${resourceName}/${endpoint}`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
        },
        body: JSON.stringify(data),
      })

      return await response.json()
    } catch (error) {
      console.error(`Error in ${endpoint}:`, error)
      throw error
    }
  }

  // Handle messages from client
  handleMessage(data) {
    switch (data.type) {
      case "openCarPlay":
        document.body.classList.remove("hidden")
        if (data.config) {
          this.volume = data.config.volume || 50
          this.range = data.config.range || 15
          this.volumeSlider.value = this.volume
          this.rangeSlider.value = this.range
          this.volumeValue.textContent = this.volume
          this.rangeValue.textContent = this.range
        }
        if (data.queue) {
          this.queue = data.queue
          this.updateQueueDisplay()
          this.updateShuffleButton()
          this.updateRepeatButton()
        }
        break

      case "closeCarPlay":
        document.body.classList.add("hidden")
        this.closeSettings()
        break

      case "queueUpdated":
        this.queue = data.queue
        this.updateQueueDisplay()
        this.updateShuffleButton()
        this.updateRepeatButton()
        break

      case "notification":
        this.showNotification(data.message)
        break

      case "musicStarted":
        this.currentSong = data.songInfo

        // Clean up the display for "YouTube Video"
        if (data.songInfo.title === "YouTube Video") {
          this.updateScrollingText(this.trackTitle, "YouTube Stream")
          this.updateScrollingText(this.trackArtist, "Audio from YouTube")
          this.trackStatus.textContent = "Ready to play"
        } else {
          this.updateScrollingText(this.trackTitle, data.songInfo.title)
          this.updateScrollingText(this.trackArtist, data.songInfo.artist)
          this.trackStatus.textContent = "Now playing"
        }

        this.duration = data.songInfo.duration || 180
        this.progress = 0
        this.isPlaying = true

        // Load thumbnail with fallback
        if (data.songInfo.thumbnail && data.songInfo.thumbnail !== "/placeholder.svg?height=300&width=300") {
          const img = new Image()
          img.crossOrigin = "anonymous"
          img.onload = () => {
            this.albumArt.src = data.songInfo.thumbnail
            this.albumArt.parentElement.classList.remove("placeholder")
          }
          img.onerror = () => {
            console.log("Failed to load thumbnail, using placeholder")
            this.albumArt.src = "/placeholder.svg?height=300&width=300"
            this.albumArt.parentElement.classList.add("placeholder")
          }
          img.src = data.songInfo.thumbnail
        } else {
          this.albumArt.src = "/placeholder.svg?height=300&width=300"
          this.albumArt.parentElement.classList.add("placeholder")
        }

        this.updatePlayPauseButton()
        this.updateProgressDisplay()
        // Removed startProgressSimulation as it's now driven by NUI updates
        break

      case "musicStopped":
        this.currentSong = null
        this.updateScrollingText(this.trackTitle, "No Music Playing")
        this.updateScrollingText(this.trackArtist, "Select a song to begin")
        this.trackStatus.textContent = ""
        this.progress = 0
        this.isPlaying = false
        this.albumArt.src = "/placeholder.svg?height=300&width=300"
        this.albumArt.parentElement.classList.add("placeholder")

        this.updatePlayPauseButton()
        this.updateProgressDisplay()
        // Removed stopProgressSimulation as it's now driven by NUI updates
        break

      case "musicPaused":
        this.isPlaying = false
        this.updatePlayPauseButton()
        this.trackStatus.textContent = "Paused"
        break

      case "musicResumed":
        this.isPlaying = true
        this.updatePlayPauseButton()
        this.trackStatus.textContent = "Playing"
        break

      case "musicLoading":
        this.trackStatus.textContent = "Loading..."
        break

      case "updateProgress":
        if (data.currentTime !== undefined) {
          this.progress = data.currentTime
        }
        if (data.duration !== undefined) {
          this.duration = data.duration
        }
        if (data.isPaused !== undefined) {
          this.isPlaying = !data.isPaused
          this.updatePlayPauseButton()
          if (data.isPaused) {
            this.trackStatus.textContent = "Paused"
          } else {
            this.trackStatus.textContent = "Playing"
          }
        }
        this.updateProgressDisplay()
        break

      case "error":
        this.showError(data.message)
        break
    }
  }
}

// Initialize CarPlay when DOM is loaded
document.addEventListener("DOMContentLoaded", () => {
  const carplay = new CarPlayController()

  // Listen for messages from the client
  window.addEventListener("message", (event) => {
    carplay.handleMessage(event.data)
  })

  // Make carplay globally accessible for debugging
  window.carplay = carplay
})

// Add CSS animations
const style = document.createElement("style")
style.textContent = `
    @keyframes slideIn {
        from {
            transform: translateX(100%);
            opacity: 0;
        }
        to {
            transform: translateX(0);
            opacity: 1;
        }
    }
    
    @keyframes slideOut {
        from {
            transform: translateX(0);
            opacity: 1;
        }
        to {
            transform: translateX(100%);
            opacity: 0;
        }
    }
`
document.head.appendChild(style)
