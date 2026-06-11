// Copyright 2025 IOTA Stiftung.
// SPDX-License-Identifier: Apache-2.0.

import type { IComponent } from "@twin.org/core";

/**
 * Consumer client component
 */
export interface IConsumerClientComponent extends IComponent {
	/**
	 * Get data
	 * @param agreementId agreementId
	 * @returns unknown
	 */
	getData(agreementId: string): Promise<unknown>;

	/**
	 * Negotiates
	 * @returns agreement Id
	 */
	negotiate(): Promise<string>;
}
