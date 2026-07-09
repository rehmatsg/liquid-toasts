package com.rehmatsg.liquid_toasts

import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.spring
import androidx.compose.ui.unit.Dp

/**
 * Single source for every shared layout constant and spring in the toast render
 * tree — the Android analog of `ToastMetrics.swift`, ported 1pt → 1dp. The
 * off-screen measurement probes must mirror the live layout's insets exactly, so
 * the inset FUNCTIONS (not just the numbers) are ported: change layout numbers
 * HERE and both the live row and the probes move in lockstep.
 *
 * Values are plain `Float` dp magnitudes (wrap with `.dp` at the call site) so
 * this object stays free of a `Density`/`Dp` dependency and unit-tests on the JVM.
 */
internal object ToastMetrics {
    // --- Row insets (multiline gets roomier insets than the hugging capsule) ---

    private fun baseHorizontalPadding(multiline: Boolean): Float = if (multiline) 18f else 16f

    fun verticalPadding(multiline: Boolean): Float = if (multiline) 14f else 11f

    /**
     * Leading inset. With a leading slot present it matches the vertical inset so
     * the glyph sits in an evenly-padded slot; otherwise it uses the base
     * horizontal inset.
     */
    fun leadingPadding(multiline: Boolean, hasLeadingSlot: Boolean): Float =
        if (hasLeadingSlot) verticalPadding(multiline) else baseHorizontalPadding(multiline)

    /**
     * Trailing inset. With an action present it matches the tighter button margin
     * (11); otherwise it mirrors the base horizontal inset.
     */
    fun trailingPadding(multiline: Boolean, hasAction: Boolean): Float =
        if (hasAction) 11f else baseHorizontalPadding(multiline)

    /** Spacing between the icon, the text column, and the action. */
    fun rowSpacing(multiline: Boolean): Float = if (multiline) 14f else 12f

    // --- Slots & column widths ---

    /** Leading glyph slot (spinner / symbol / progress ring). */
    const val ICON_SLOT: Float = 22f

    /** Determinate progress ring diameter (sits inside the icon slot). */
    const val PROGRESS_RING_SIZE: Float = 20f

    /** Leading avatar / thumbnail diameter. */
    const val AVATAR_SIZE: Float = 26f

    /** Single-line text column cap so the capsule never spans the screen. */
    const val TEXT_COLUMN_MAX_WIDTH: Float = 260f

    /** Fixed linear progress bar width on a hugging capsule. */
    const val LINEAR_PROGRESS_WIDTH: Float = 160f

    /** Estimated action button width until its first real measurement lands. */
    const val ACTION_WIDTH_ESTIMATE: Float = 72f

    /** Floor for the multiline probe's reference text width. */
    const val PROBE_MIN_REFERENCE_WIDTH: Float = 120f

    // --- Multiline geometry ---

    const val MULTILINE_SIDE_MARGIN: Float = 20f
    const val MULTILINE_MAX_WIDTH: Float = 440f

    /**
     * Width of a multiline toast: near-full device width, comfortably inset,
     * capped so it never stretches unwieldily wide on tablets / landscape.
     */
    fun multilineWidth(screenWidthDp: Float): Float =
        minOf(MULTILINE_MAX_WIDTH, screenWidthDp - MULTILINE_SIDE_MARGIN * 2)

    // --- Shape ---

    const val MULTILINE_CORNER_RADIUS: Float = 22f

    /** Large radius the surface clamps to a capsule on compact toasts. */
    const val CAPSULE_CORNER_RADIUS: Float = 99f

    // --- Drag ---

    const val DRAG_MIN_DISTANCE: Float = 6f

    /** Translation past which a drag toward the edge commits to dismissal. */
    const val DRAG_COMMIT_DISTANCE: Float = 28f

    /** Predicted end translation past which a flick commits regardless of travel. */
    const val FLICK_DISTANCE: Float = 140f

    /** Damping applied when dragging away from the dismiss edge. */
    const val RUBBER_BAND_FACTOR: Float = 0.35f

    // --- Springs ---
    //
    // Ported from the iOS spring(response:dampingFraction:) values. Compose
    // stiffness is the undamped natural frequency squared: (2π / response)².
    //   stackSpring:  response 0.42 → (2π/0.42)² ≈ 223.8
    //   settleSpring: response 0.35 → (2π/0.35)² ≈ 322.2

    /** The stack's shared motion: entrances, reorders, morphs, width changes. */
    val stackSpring = spring<Float>(dampingRatio = 0.82f, stiffness = 224f)

    /** Snappier settle: drag return, icon swaps. */
    val settleSpring = spring<Float>(dampingRatio = 0.7f, stiffness = 322f)

    // Dp-typed twins of the springs above (identical parameters). `animateDpAsState`
    // needs a `FiniteAnimationSpec<Dp>`; keeping the parameters here — rather than
    // reflecting them off the Float specs — is the single-source rule for motion.
    val stackSpringDp = spring<Dp>(dampingRatio = 0.82f, stiffness = 224f)
    val settleSpringDp = spring<Dp>(dampingRatio = 0.7f, stiffness = 322f)

    // Offset-typed twin for the entrance/drag translation animations.
    val stackSpringOffset = spring<androidx.compose.ui.geometry.Offset>(dampingRatio = 0.82f, stiffness = 224f)

    /** Reduce-Motion analog duration (ms) for the disabled-animations path. */
    const val REDUCED_MOTION_DURATION_MS: Int = 200

    // Compose default token, referenced so callers can build matching offset/size specs.
    @Suppress("unused")
    val stackVisibilityThreshold: Float = Spring.DefaultDisplacementThreshold
}
