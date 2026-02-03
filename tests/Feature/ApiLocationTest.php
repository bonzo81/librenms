<?php

/**
 * ApiLocationTest.php
 *
 * Test for Location API endpoints
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <https://www.gnu.org/licenses/>.
 *
 * @link       https://www.librenms.org
 *
 * @copyright  2025 LibreNMS
 * @author     LibreNMS Contributors
 */

namespace Tests\Feature;

use App\Models\ApiToken;
use App\Models\Location;
use App\Models\User;
use Illuminate\Foundation\Testing\DatabaseTransactions;
use LibreNMS\Tests\DBTestCase;

final class ApiLocationTest extends DBTestCase
{
    use DatabaseTransactions;

    public function testEditLocationWithDecimalCoordinates(): void
    {
        /** @var User $user */
        $user = User::factory()->admin()->create();
        $token = ApiToken::generateToken($user);
        
        /** @var Location $location */
        $location = Location::factory()->create([
            'location' => 'Test Location',
            'lat' => '51.50354111',
            'lng' => '-0.12766972',
        ]);

        // Update the location with new coordinates
        $newLat = '40.71277800';
        $newLng = '-74.00597200';
        
        $response = $this->json(
            'PATCH',
            "/api/v0/locations/{$location->id}",
            [
                'lat' => $newLat,
                'lng' => $newLng,
            ],
            ['X-Auth-Token' => $token->token_hash]
        );

        $response->assertStatus(201)
            ->assertJson([
                'status' => 'ok',
                'message' => 'Location updated successfully',
            ]);

        // Verify the database was updated correctly
        $location->refresh();
        $this->assertEquals($newLat, $location->lat);
        $this->assertEquals($newLng, $location->lng);
    }

    public function testEditLocationByName(): void
    {
        /** @var User $user */
        $user = User::factory()->admin()->create();
        $token = ApiToken::generateToken($user);
        
        /** @var Location $location */
        $location = Location::factory()->create([
            'location' => 'Test Location Name',
            'lat' => '51.50354111',
            'lng' => '-0.12766972',
        ]);

        // Update the location by name with new coordinates
        $newLat = '48.85661400';
        $newLng = '2.35222190';
        
        $response = $this->json(
            'PATCH',
            '/api/v0/locations/' . urlencode($location->location),
            [
                'lat' => $newLat,
                'lng' => $newLng,
            ],
            ['X-Auth-Token' => $token->token_hash]
        );

        $response->assertStatus(201)
            ->assertJson([
                'status' => 'ok',
                'message' => 'Location updated successfully',
            ]);

        // Verify the database was updated correctly
        $location->refresh();
        $this->assertEquals($newLat, $location->lat);
        $this->assertEquals($newLng, $location->lng);
    }

    public function testEditLocationWithNullCoordinates(): void
    {
        /** @var User $user */
        $user = User::factory()->admin()->create();
        $token = ApiToken::generateToken($user);
        
        /** @var Location $location */
        $location = Location::factory()->create([
            'location' => 'Test Location Null',
            'lat' => '51.50354111',
            'lng' => '-0.12766972',
        ]);

        // Update the location with null coordinates
        $response = $this->json(
            'PATCH',
            "/api/v0/locations/{$location->id}",
            [
                'lat' => null,
                'lng' => null,
            ],
            ['X-Auth-Token' => $token->token_hash]
        );

        $response->assertStatus(201);

        // Verify the database was updated correctly
        $location->refresh();
        $this->assertNull($location->lat);
        $this->assertNull($location->lng);
    }
}
