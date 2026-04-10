"""Unit tests for src/python/media/_image_ops.py."""

import os
from pathlib import Path
from unittest.mock import MagicMock, patch

import numpy as np
import pytest

from src.python.media._image_ops import (
    VALID_EXTS,
    ProcessingConfig,
    _dedupe_path,
    crop_image,
    detect_content_bbox,
    ensure_output_path,
    imwrite_retry,
    list_images,
)

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def _solid_bgr(height: int = 10, width: int = 10, value: int = 0) -> np.ndarray:
    """Create a solid-colour BGR image."""
    return np.full((height, width, 3), value, dtype=np.uint8)


def _bgr_with_content(
    height: int = 20,
    width: int = 20,
    border: int = 4,
    content_value: int = 128,
    border_value: int = 0,
) -> np.ndarray:
    """Create a BGR image with a uniform border and a content region."""
    img = np.full((height, width, 3), border_value, dtype=np.uint8)
    img[border : height - border, border : width - border] = content_value
    return img


def _bgra_with_alpha(
    height: int = 20,
    width: int = 20,
    border: int = 4,
) -> np.ndarray:
    """Create a BGRA image: transparent border, fully-opaque content."""
    img = np.zeros((height, width, 4), dtype=np.uint8)
    img[:, :, :3] = 200  # visible colour everywhere
    # Border pixels are fully transparent; content pixels are opaque
    img[border : height - border, border : width - border, 3] = 255
    return img


# ---------------------------------------------------------------------------
# VALID_EXTS
# ---------------------------------------------------------------------------


class TestValidExts:
    def test_contains_expected_extensions(self):
        assert ".png" in VALID_EXTS
        assert ".jpg" in VALID_EXTS
        assert ".jpeg" in VALID_EXTS

    def test_does_not_contain_unsupported(self):
        assert ".bmp" not in VALID_EXTS
        assert ".gif" not in VALID_EXTS


# ---------------------------------------------------------------------------
# detect_content_bbox
# ---------------------------------------------------------------------------


class TestDetectContentBbox:
    def test_solid_black_returns_none(self):
        """A completely black image has no content and should return None."""
        img = _solid_bgr(value=0)
        assert detect_content_bbox(img, low_threshold=5, high_threshold=250) is None

    def test_solid_white_returns_none(self):
        """A completely white image has no content and should return None."""
        img = _solid_bgr(value=255)
        assert detect_content_bbox(img, low_threshold=5, high_threshold=250) is None

    def test_image_with_content_returns_bbox(self):
        """Image with a content region surrounded by a black border returns correct bbox."""
        border = 4
        img = _bgr_with_content(height=20, width=20, border=border, content_value=128)
        bbox = detect_content_bbox(img, low_threshold=5, high_threshold=250, min_area=1, padding=0)
        assert bbox is not None
        y0, y1, x0, x1 = bbox
        assert y0 == border
        assert y1 == 20 - border - 1
        assert x0 == border
        assert x1 == 20 - border - 1

    def test_padding_is_applied(self):
        """Padding expands the returned bbox by the requested amount (clamped to boundaries)."""
        border = 4
        padding = 2
        img = _bgr_with_content(height=20, width=20, border=border, content_value=128)
        bbox = detect_content_bbox(
            img, low_threshold=5, high_threshold=250, min_area=1, padding=padding
        )
        assert bbox is not None
        y0, y1, x0, x1 = bbox
        assert y0 == border - padding
        assert y1 == 20 - border - 1 + padding
        assert x0 == border - padding
        assert x1 == 20 - border - 1 + padding

    def test_padding_clamped_at_image_boundary(self):
        """Padding cannot push coordinates outside the image dimensions."""
        # Single pixel of content at position (0,0) with large padding
        img = np.zeros((10, 10, 3), dtype=np.uint8)
        img[0, 0] = 128  # single content pixel
        bbox = detect_content_bbox(img, low_threshold=5, high_threshold=250, min_area=1, padding=99)
        assert bbox is not None
        y0, y1, x0, x1 = bbox
        assert y0 >= 0
        assert x0 >= 0
        assert y1 <= 9
        assert x1 <= 9

    def test_min_area_filters_small_content(self):
        """Content that is smaller than min_area should cause None to be returned."""
        # Single pixel of content
        img = np.zeros((10, 10, 3), dtype=np.uint8)
        img[5, 5] = 128
        assert (
            detect_content_bbox(img, low_threshold=5, high_threshold=250, min_area=256, padding=0)
            is None
        )

    def test_alpha_channel_path(self):
        """With preserve_alpha=True on a 4-channel image, transparent pixels are ignored."""
        border = 4
        img = _bgra_with_alpha(height=20, width=20, border=border)
        bbox = detect_content_bbox(
            img, low_threshold=5, high_threshold=250, min_area=1, padding=0, preserve_alpha=True
        )
        assert bbox is not None
        y0, y1, x0, x1 = bbox
        assert y0 == border
        assert x0 == border

    def test_alpha_threshold_respected(self):
        """Pixels with alpha <= alpha_threshold should not be treated as content."""
        img = np.zeros((10, 10, 4), dtype=np.uint8)
        img[:, :, :3] = 128
        img[:, :, 3] = 100  # all semi-transparent
        # alpha_threshold=100 means pixels with alpha <= 100 are NOT content
        result = detect_content_bbox(img, preserve_alpha=True, alpha_threshold=100, padding=0)
        assert result is None

    def test_grayscale_image(self):
        """A 2-D (grayscale) image with content in centre returns a valid bbox."""
        img = np.zeros((10, 10), dtype=np.uint8)
        img[3:7, 3:7] = 128
        bbox = detect_content_bbox(img, low_threshold=5, high_threshold=250, padding=0, min_area=1)
        assert bbox is not None


# ---------------------------------------------------------------------------
# imwrite_retry
# ---------------------------------------------------------------------------


class TestImwriteRetry:
    def test_success_on_first_attempt(self):
        with patch("src.python.media._image_ops.cv2.imwrite", return_value=True) as mock_write:
            result = imwrite_retry(
                "/fake/path.png", np.zeros((4, 4, 3), dtype=np.uint8), attempts=3
            )
        assert result is True
        assert mock_write.call_count == 1

    def test_success_after_retry(self):
        side_effects = [False, True]
        with patch(
            "src.python.media._image_ops.cv2.imwrite", side_effect=side_effects
        ) as mock_write:
            with patch("src.python.media._image_ops.time.sleep"):
                result = imwrite_retry(
                    "/fake/path.png", np.zeros((4, 4, 3), dtype=np.uint8), attempts=3
                )
        assert result is True
        assert mock_write.call_count == 2

    def test_failure_after_all_attempts(self):
        with patch("src.python.media._image_ops.cv2.imwrite", return_value=False):
            with patch("src.python.media._image_ops.time.sleep"):
                result = imwrite_retry(
                    "/fake/path.png", np.zeros((4, 4, 3), dtype=np.uint8), attempts=3
                )
        assert result is False

    def test_attempts_clamped_to_one(self):
        """attempts=0 should still make exactly one attempt."""
        with patch("src.python.media._image_ops.cv2.imwrite", return_value=True) as mock_write:
            result = imwrite_retry(
                "/fake/path.png", np.zeros((4, 4, 3), dtype=np.uint8), attempts=0
            )
        assert result is True
        assert mock_write.call_count == 1


# ---------------------------------------------------------------------------
# ensure_output_path
# ---------------------------------------------------------------------------


class TestEnsureOutputPath:
    def test_in_place_returns_input_path(self, tmp_path):
        in_path = str(tmp_path / "img.jpg")
        result = ensure_output_path(
            in_path,
            output_dir=str(tmp_path / "out"),
            root=str(tmp_path),
            suffix="_cropped",
            no_suffix=False,
            in_place=True,
        )
        assert result == in_path

    def test_non_in_place_with_suffix(self, tmp_path):
        in_path = str(tmp_path / "img.jpg")
        out_dir = str(tmp_path / "out")
        result = ensure_output_path(
            in_path,
            output_dir=out_dir,
            root=str(tmp_path),
            suffix="_cropped",
            no_suffix=False,
            in_place=False,
        )
        assert result == os.path.join(out_dir, "img_cropped.jpg")

    def test_non_in_place_no_suffix(self, tmp_path):
        in_path = str(tmp_path / "img.jpg")
        out_dir = str(tmp_path / "out")
        result = ensure_output_path(
            in_path,
            output_dir=out_dir,
            root=str(tmp_path),
            suffix="_cropped",
            no_suffix=True,
            in_place=False,
        )
        assert result == os.path.join(out_dir, "img.jpg")

    def test_deduplication_when_output_exists(self, tmp_path):
        in_path = str(tmp_path / "img.jpg")
        out_dir = tmp_path / "out"
        out_dir.mkdir()
        # Pre-create the expected output to trigger dedup
        (out_dir / "img_cropped.jpg").write_text("existing")
        result = ensure_output_path(
            in_path,
            output_dir=str(out_dir),
            root=str(tmp_path),
            suffix="_cropped",
            no_suffix=False,
            in_place=False,
        )
        assert result == str(out_dir / "img_cropped_1.jpg")

    def test_raises_without_output_dir_when_not_in_place(self, tmp_path):
        with pytest.raises(ValueError, match="requires output_dir"):
            ensure_output_path(
                str(tmp_path / "img.jpg"),
                output_dir=None,
                root=str(tmp_path),
                suffix="_cropped",
                no_suffix=False,
                in_place=False,
            )

    def test_raises_without_root_when_not_in_place(self, tmp_path):
        with pytest.raises(ValueError, match="requires 'root'"):
            ensure_output_path(
                str(tmp_path / "img.jpg"),
                output_dir=str(tmp_path / "out"),
                root=None,
                suffix="_cropped",
                no_suffix=False,
                in_place=False,
            )

    def test_preserves_subdir_structure(self, tmp_path):
        """Files in subdirectories should mirror the structure under output_dir."""
        sub = tmp_path / "sub"
        sub.mkdir()
        in_path = str(sub / "img.jpg")
        out_dir = str(tmp_path / "out")
        result = ensure_output_path(
            in_path,
            output_dir=out_dir,
            root=str(tmp_path),
            suffix="_cropped",
            no_suffix=False,
            in_place=False,
        )
        assert result == os.path.join(out_dir, "sub", "img_cropped.jpg")


# ---------------------------------------------------------------------------
# crop_image
# ---------------------------------------------------------------------------


class TestCropImage:
    def test_no_content_returns_original(self):
        """If detect_content_bbox returns None, original image is returned unchanged."""
        img = _solid_bgr(value=0)
        result = crop_image(img, low_threshold=5, high_threshold=250, min_area=256, padding=0)
        assert result is img

    def test_crops_to_content(self):
        """Content region is returned when a valid bbox is detected."""
        border = 4
        content_val = 128
        img = _bgr_with_content(height=20, width=20, border=border, content_value=content_val)
        result = crop_image(img, low_threshold=5, high_threshold=250, min_area=1, padding=0)
        expected_size = 20 - 2 * border
        assert result.shape[0] == expected_size
        assert result.shape[1] == expected_size


# ---------------------------------------------------------------------------
# list_images
# ---------------------------------------------------------------------------


class TestListImages:
    def test_returns_only_valid_extensions(self, tmp_path):
        (tmp_path / "a.png").write_bytes(b"")
        (tmp_path / "b.jpg").write_bytes(b"")
        (tmp_path / "c.txt").write_bytes(b"")
        result = list_images(str(tmp_path))
        names = [Path(p).name for p in result]
        assert "a.png" in names
        assert "b.jpg" in names
        assert "c.txt" not in names

    def test_excludes_cropped_folder(self, tmp_path):
        cropped = tmp_path / "Cropped"
        cropped.mkdir()
        (tmp_path / "ok.jpg").write_bytes(b"")
        (cropped / "skip.jpg").write_bytes(b"")
        result = list_images(str(tmp_path), recurse=True)
        names = [Path(p).name for p in result]
        assert "ok.jpg" in names
        assert "skip.jpg" not in names

    def test_recurse_finds_nested_files(self, tmp_path):
        sub = tmp_path / "sub"
        sub.mkdir()
        (sub / "nested.png").write_bytes(b"")
        result_no_recurse = list_images(str(tmp_path), recurse=False)
        result_recurse = list_images(str(tmp_path), recurse=True)
        names_no = [Path(p).name for p in result_no_recurse]
        names_yes = [Path(p).name for p in result_recurse]
        assert "nested.png" not in names_no
        assert "nested.png" in names_yes

    def test_result_is_sorted(self, tmp_path):
        for name in ["z.jpg", "a.png", "m.jpeg"]:
            (tmp_path / name).write_bytes(b"")
        result = list_images(str(tmp_path))
        assert result == sorted(result)


# ---------------------------------------------------------------------------
# ProcessingConfig
# ---------------------------------------------------------------------------


class TestProcessingConfig:
    def _make_args(self, **overrides):
        defaults = dict(
            retry_writes=3,
            low_threshold=5,
            high_threshold=250,
            min_area=256,
            padding=2,
            preserve_alpha=False,
            alpha_threshold=0,
            suffix="_cropped",
            no_suffix=False,
            in_place=False,
        )
        defaults.update(overrides)
        args = MagicMock()
        for k, v in defaults.items():
            setattr(args, k, v)
        return args

    def test_attributes_set_from_args(self, tmp_path):
        args = self._make_args(retry_writes=5, suffix="_out")
        cfg = ProcessingConfig(args, root=str(tmp_path), folder=str(tmp_path))
        assert cfg.retry_writes == 5
        assert cfg.suffix == "_out"
        assert cfg.root == str(tmp_path)
        assert cfg.folder == str(tmp_path)

    def test_all_expected_attributes_present(self, tmp_path):
        args = self._make_args()
        cfg = ProcessingConfig(args, root=str(tmp_path), folder=str(tmp_path))
        for attr in (
            "retry_writes",
            "low_threshold",
            "high_threshold",
            "min_area",
            "padding",
            "preserve_alpha",
            "alpha_threshold",
            "suffix",
            "no_suffix",
            "in_place",
            "root",
            "folder",
        ):
            assert hasattr(cfg, attr), f"Missing attribute: {attr}"
