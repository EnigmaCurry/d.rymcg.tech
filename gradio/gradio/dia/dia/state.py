from dataclasses import dataclass
from typing import Optional

import torch

from .config import DiaConfig


def create_attn_mask(
    q_padding_mask_1d: torch.Tensor,
    k_padding_mask_1d: torch.Tensor,
    device: torch.device,
    is_causal: bool = False,
) -> torch.Tensor:
    """
    Creates the attention mask (self or cross) mimicking JAX segment ID logic.
    """
    # B1, Tq = q_padding_mask_1d.shape
    # B2, Tk = k_padding_mask_1d.shape

    p_mask_q = q_padding_mask_1d.unsqueeze(2)  # Shape [B, Tq, 1]
    p_mask_k = k_padding_mask_1d.unsqueeze(1)  # Shape [B, 1, Tk]

    # Condition A: Non-padding query attends to non-padding key
    non_pad_attends_non_pad = p_mask_q & p_mask_k  # Shape [B, Tq, Tk]

    # Condition B: Padding query attends to padding key
    pad_attends_pad = (~p_mask_q) & (~p_mask_k)  # Shape [B, Tq, Tk]

    # Combine: True if padding status is compatible (both non-pad OR both pad)
    mask = non_pad_attends_non_pad | pad_attends_pad  # Shape [B, Tq, Tk]

    if is_causal:
        # assert Tq == Tk, "Causal mask requires query and key sequence lengths to be equal"
        causal_mask_2d = torch.tril(torch.ones_like(mask[0], dtype=torch.bool, device=device))  # Shape [B, Tq, Tk]
        causal_mask = mask & causal_mask_2d  # Shape [B, Tq, Tk]
        return causal_mask.unsqueeze(1)  # Shape [B, 1, Tq, Tk]
    else:
        return mask.unsqueeze(1)  # Shape [B, 1, Tq, Tk]


@dataclass
class EncoderInferenceState:
    """Parameters specifically for encoder inference."""

    max_seq_len: int
    device: torch.device
    positions: torch.Tensor
    padding_mask: torch.Tensor
    attn_mask: torch.Tensor

    @classmethod
    def new(cls, config: DiaConfig, cond_src: torch.Tensor) -> "EncoderInferenceState":
        """Creates EtorchrInferenceParams from DiaConfig and a device."""
        device = cond_src.device

        positions = torch.arange(
            config.encoder_config.max_position_embeddings, dtype=torch.float32, device=device
        ).unsqueeze(0)
        padding_mask = (cond_src.squeeze(1) != 0).to(device).repeat_interleave(2, dim=0)
        attn_mask = create_attn_mask(padding_mask, padding_mask, device, is_causal=False)

        return cls(
            max_seq_len=config.encoder_config.max_position_embeddings,
            device=device,
            positions=positions,
            padding_mask=padding_mask,
            attn_mask=attn_mask,
        )


class KVCache(torch.nn.Module):
    k: torch.Tensor
    v: torch.Tensor

    def __init__(
        self,
        batch_size: int,
        num_heads: int,
        max_len: int,
        head_dim: int,
        dtype: torch.dtype,
        device: torch.device,
        k: torch.Tensor | None = None,
        v: torch.Tensor | None = None,
    ):
        k = torch.zeros((2 * batch_size, num_heads, max_len, head_dim), dtype=dtype, device=device) if k is None else k
        v = torch.zeros((2 * batch_size, num_heads, max_len, head_dim), dtype=dtype, device=device) if v is None else v
        super().__init__()

        self.register_buffer("k", k)
        self.register_buffer("v", v)

    @classmethod
    def from_kv(cls, k: torch.Tensor, v: torch.Tensor) -> "KVCache":
        return cls(
            batch_size=k.shape[0] // 2,
            num_heads=k.shape[1],
            max_len=k.shape[2],
            head_dim=k.shape[3],
            dtype=k.dtype,
            device=k.device,
            k=k,
            v=v,
        )

    def update(self, k: torch.Tensor, v: torch.Tensor, current_idx: torch.Tensor) -> tuple[torch.Tensor, torch.Tensor]:
        k_out, v_out = self.k, self.v
        k_out[:, :, current_idx, :] = k
        v_out[:, :, current_idx, :] = v
        return self.k, self.v

    def prefill(self, k: torch.Tensor, v: torch.Tensor):
        prefill_len = k.shape[2]
        self.k[:, :, :prefill_len, :] = k
        self.v[:, :, :prefill_len, :] = v


@dataclass
class DecoderInferenceState:
    """Parameters specifically for decoder inference."""

    device: torch.device
    dtype: torch.dtype
    enc_out: torch.Tensor
    enc_positions: torch.Tensor
    dec_positions: torch.Tensor
    self_attn_cache: list[KVCache]
    cross_attn_cache: list[KVCache]
    casual_attn_mask: torch.Tensor
    cross_attn_mask: torch.Tensor

    @classmethod
    def new(
        cls,
        config: DiaConfig,
        enc_state: EncoderInferenceState,
        enc_out: torch.Tensor,
        dec_cross_attn_cache: list[KVCache],
        compute_dtype: torch.dtype,
        max_generation_length: Optional[int] = None,
    ) -> "DecoderInferenceState":
        """Creates DecoderInferenceParams from DiaConfig and a device."""
        device = enc_out.device
        max_audio_len = max_generation_length or config.decoder_config.max_position_embeddings
        batch_size = enc_out.shape[0] // 2

        dec_positions = torch.full((2 * batch_size, 1), fill_value=0, dtype=torch.int32, device=device)
        causal_mask = torch.tril(torch.ones(max_audio_len, max_audio_len, dtype=torch.bool, device=device))
        dec_mask = torch.ones((2 * batch_size, 1), dtype=torch.bool, device=device)
        cross_attn_mask = create_attn_mask(dec_mask, enc_state.padding_mask, device, is_causal=False)

        self_attn_cache = [
            KVCache(
                batch_size,
                config.decoder_config.num_key_value_heads,
                max_audio_len,
                config.decoder_config.head_dim,
                compute_dtype,
                device,
            )
            for _ in range(config.decoder_config.num_hidden_layers)
        ]

        return cls(
            device=device,
            dtype=compute_dtype,
            enc_out=enc_out,
            enc_positions=enc_state.positions,
            dec_positions=dec_positions,
            self_attn_cache=self_attn_cache,
            cross_attn_cache=dec_cross_attn_cache,
            casual_attn_mask=causal_mask,
            cross_attn_mask=cross_attn_mask,
        )

    def prepare_step(self, step_from: int, step_to: int | None = None) -> None:
        if step_to is None:
            step_to = step_from + 1
        self.dec_positions = torch.arange(step_from, step_to, dtype=torch.int32, device=self.device).unsqueeze(0)


@dataclass
class DecoderOutput:
    generated_tokens: torch.Tensor
    prefill_steps: list[int]

    @classmethod
    def new(cls, batch_size: int, config: DiaConfig, device: torch.device) -> "DecoderOutput":
        max_audio_len = config.decoder_config.max_position_embeddings
        return cls(
            generated_tokens=torch.full(
                (batch_size, max_audio_len, config.decoder_config.num_channels),
                fill_value=-1,
                dtype=torch.int,
                device=device,
            ),
            prefill_steps=[],
        )

    def get_tokens_at(self, step_from: int, step_to: int | None = None) -> torch.Tensor:
        if step_to is None:
            step_to = step_from + 1
        return self.generated_tokens[:, step_from:step_to, :]

    def update_one(self, dec_out: torch.Tensor, step: int, apply_mask: bool = False):
        dec_out = dec_out.to(self.generated_tokens.dtype)
        if apply_mask:
            mask = self.generated_tokens[:, step, :] == -1
            self.generated_tokens[:, step, :] = torch.where(mask, dec_out, self.generated_tokens[:, step, :])
        else:
            self.generated_tokens[:, step, :] = dec_out

    def prefill(self, dec_out: torch.Tensor, prefill_steps: list[int]):
        length = dec_out.shape[1]
        self.generated_tokens[:, :length, :] = dec_out
        self.prefill_steps = prefill_steps
